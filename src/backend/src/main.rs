use std::pin::Pin;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::Duration;
use std::{fs, path::PathBuf, sync::Mutex};

use anyhow::{bail, Context, Result};
use futures_util::StreamExt;
use tokio::sync::broadcast;
use tonic::{transport::Server, Request, Response, Status};
use tracing::{info, warn};
use tracing_appender::rolling;
use tracing_subscriber::prelude::*;

pub mod carnine {
    tonic::include_proto!("carnine");
}

mod audio_engine;
mod config;
mod database;
mod media_player;
mod storage_events;

use carnine::{
    audio_service_server::{AudioService, AudioServiceServer},
    carnine_service_server::{CarnineService, CarnineServiceServer},
    config_service_server::{ConfigService, ConfigServiceServer},
    media_service_server::{MediaService, MediaServiceServer},
    AddPlaylistEntryRequest, AudioEvent, CanData, CanDataRequest, CanDataResponse, CommandResponse,
    Configuration, ConfigurationResponse, CreatePlaylistRequest, Empty, GetPlaylistRequest,
    LibraryEvent, ListPlaylistsResponse, PlayPlaylistRequest, PlayQueueEntryRequest, PlayRequest,
    PlayerEvent, PlayerState, Playlist, PlaylistEntry, RescanMediaRequest, SearchMediaRequest,
    SearchMediaResponse, ServiceVersion, UpdateConfigurationRequest,
};

use database::ResumeState;
use media_player::MediaPlayer;

#[derive(Debug, Default)]
pub struct CarnineServiceImpl;

#[derive(Clone)]
pub struct MediaServiceImpl {
    player: Arc<MediaPlayer>,
    database_path: PathBuf,
    media_folders: Vec<PathBuf>,
    supported_formats: Vec<String>,
    resume_mode: String,
    library_events: broadcast::Sender<LibraryEvent>,
    next_scan_id: Arc<AtomicU64>,
}

pub struct ConfigServiceImpl {
    configuration: Mutex<config::Config>,
    path: PathBuf,
}

impl ConfigServiceImpl {
    fn new(configuration: config::Config, path: PathBuf) -> Self {
        Self {
            configuration: Mutex::new(configuration),
            path,
        }
    }

    fn snapshot(&self) -> Configuration {
        let configuration = self
            .configuration
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        configuration_to_proto(&configuration)
    }
}

impl MediaServiceImpl {
    fn new(
        audio_config: &config::AudioConfig,
        database_path: PathBuf,
        media_folders: Vec<PathBuf>,
        supported_formats: Vec<String>,
        resume_mode: String,
    ) -> Self {
        let (library_events, _) = broadcast::channel(64);
        Self {
            player: Arc::new(MediaPlayer::from_audio_config(audio_config)),
            database_path,
            media_folders,
            supported_formats,
            resume_mode,
            library_events,
            next_scan_id: Arc::new(AtomicU64::new(1)),
        }
    }

    #[cfg(test)]
    fn with_player(
        player: MediaPlayer,
        database_path: PathBuf,
        media_folders: Vec<PathBuf>,
        supported_formats: Vec<String>,
        resume_mode: String,
    ) -> Self {
        let (library_events, _) = broadcast::channel(64);
        Self {
            player: Arc::new(player),
            database_path,
            media_folders,
            supported_formats,
            resume_mode,
            library_events,
            next_scan_id: Arc::new(AtomicU64::new(1)),
        }
    }

    fn save_resume_state(&self) -> anyhow::Result<()> {
        let database = database::Database::open(&self.database_path)?;
        database.save_resume_state(&ResumeState {
            playlist_id: self.player.playlist_id(),
            playlist_entry_id: self.player.playlist_entry_id(),
            position_ms: self.player.position_ms(),
            resume_mode: self.resume_mode.clone(),
        })
    }

    fn restore_resume_state(&self) -> anyhow::Result<()> {
        let database = database::Database::open(&self.database_path)?;
        let Some(state) = database.load_resume_state()? else {
            return Ok(());
        };
        let Some(playlist_id) = state.playlist_id else {
            return Ok(());
        };
        let entries = database.playlist_media_paths(playlist_id)?;
        self.player.play_playlist(
            playlist_id,
            entries,
            state.playlist_entry_id,
            state.position_ms,
            &self.resume_mode,
        )?;
        Ok(())
    }

    fn scan_events(&self) -> anyhow::Result<Vec<LibraryEvent>> {
        let database = database::Database::open(&self.database_path)?;
        let scan_id = self.next_scan_id.fetch_add(1, Ordering::Relaxed);
        let mut events = vec![LibraryEvent {
            event: "scan_started".to_string(),
            scan_id,
            ..Default::default()
        }];
        let mut processed = 0_u64;
        let mut imported = 0_u64;
        for folder in &self.media_folders {
            match database.rescan_folder(folder, &self.supported_formats) {
                Ok(count) => {
                    imported += count as u64;
                    processed += count as u64;
                    events.push(LibraryEvent {
                        event: "progress".to_string(),
                        scan_id,
                        processed,
                        imported,
                        path: folder.display().to_string(),
                        ..Default::default()
                    });
                }
                Err(error) => events.push(LibraryEvent {
                    event: "error".to_string(),
                    scan_id,
                    path: folder.display().to_string(),
                    message: error.to_string(),
                    ..Default::default()
                }),
            }
        }
        events.push(LibraryEvent {
            event: "scan_completed".to_string(),
            scan_id,
            processed,
            imported,
            ..Default::default()
        });
        Ok(events)
    }

    fn rescan_library(&self) -> anyhow::Result<()> {
        for event in self.scan_events()? {
            let _ = self.library_events.send(event);
        }
        Ok(())
    }
}

#[tonic::async_trait]
impl ConfigService for ConfigServiceImpl {
    async fn get_configuration(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<Configuration>, Status> {
        Ok(Response::new(self.snapshot()))
    }

    async fn update_configuration(
        &self,
        request: Request<UpdateConfigurationRequest>,
    ) -> Result<Response<ConfigurationResponse>, Status> {
        let configuration = request
            .into_inner()
            .configuration
            .context("configuration is required")
            .map_err(|error| Status::invalid_argument(error.to_string()))?;
        let updated = configuration_from_proto(&configuration)
            .map_err(|error| Status::invalid_argument(error.to_string()))?;
        let toml = toml::to_string_pretty(&updated)
            .map_err(|error| Status::internal(error.to_string()))?;
        let temporary_path = self.path.with_extension("toml.tmp");
        fs::write(&temporary_path, toml).map_err(|error| Status::internal(error.to_string()))?;
        fs::rename(&temporary_path, &self.path)
            .map_err(|error| Status::internal(error.to_string()))?;
        *self
            .configuration
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = updated;

        Ok(Response::new(ConfigurationResponse {
            success: true,
            message: "configuration saved; restart required".to_string(),
            configuration: Some(configuration),
            restart_required: true,
        }))
    }
}

pub struct AudioServiceImpl {
    events: broadcast::Sender<AudioEvent>,
    backend: String,
    device: String,
}

impl AudioServiceImpl {
    fn new(configuration: &config::AudioConfig) -> Self {
        let (events, _) = broadcast::channel(32);
        Self {
            events,
            backend: configuration.backend.clone(),
            device: configuration.device.clone(),
        }
    }

    pub fn publish(&self, event: &str, message: impl Into<String>) {
        let _ = self.events.send(AudioEvent {
            event: event.to_string(),
            message: message.into(),
        });
    }
}

#[tonic::async_trait]
impl CarnineService for CarnineServiceImpl {
    async fn get_can_data(
        &self,
        request: Request<CanDataRequest>,
    ) -> Result<Response<CanDataResponse>, Status> {
        let req = request.into_inner();
        info!("Received CAN data request for sensor: {}", req.sensor_id);

        let data = vec![CanData {
            sensor_id: req.sensor_id.clone(),
            value: 42.0,
            timestamp: chrono::Utc::now().timestamp(),
        }];

        let response = CanDataResponse { data };
        Ok(Response::new(response))
    }
}

#[tonic::async_trait]
impl MediaService for MediaServiceImpl {
    type StreamPlayerEventsStream =
        Pin<Box<dyn futures_util::Stream<Item = Result<PlayerEvent, Status>> + Send>>;
    type RescanMediaStream = tokio_stream::Iter<std::vec::IntoIter<Result<LibraryEvent, Status>>>;
    type StreamLibraryEventsStream =
        Pin<Box<dyn futures_util::Stream<Item = Result<LibraryEvent, Status>> + Send>>;

    async fn get_service_version(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<ServiceVersion>, Status> {
        Ok(Response::new(ServiceVersion {
            major: 0,
            minor: 1,
            patch: 0,
        }))
    }

    async fn play(
        &self,
        request: Request<PlayRequest>,
    ) -> Result<Response<CommandResponse>, Status> {
        self.command("play", request.into_inner().media_path)
    }

    async fn pause(&self, _request: Request<Empty>) -> Result<Response<CommandResponse>, Status> {
        self.command("pause", String::new())
    }

    async fn stop(&self, _request: Request<Empty>) -> Result<Response<CommandResponse>, Status> {
        self.command("stop", String::new())
    }

    async fn next(&self, _request: Request<Empty>) -> Result<Response<CommandResponse>, Status> {
        self.command("next", String::new())
    }

    async fn previous(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<CommandResponse>, Status> {
        self.command("previous", String::new())
    }

    async fn restart_current_track(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<CommandResponse>, Status> {
        self.command("restart", String::new())
    }

    async fn play_queue_entry(
        &self,
        request: Request<PlayQueueEntryRequest>,
    ) -> Result<Response<CommandResponse>, Status> {
        self.command("queue-entry", request.into_inner().index.to_string())
    }

    async fn play_playlist(
        &self,
        request: Request<PlayPlaylistRequest>,
    ) -> Result<Response<CommandResponse>, Status> {
        let playlist_id = request.into_inner().playlist_id as i64;
        let resume_state = database::Database::open(&self.database_path)
            .map_err(|error| Status::internal(error.to_string()))?
            .load_resume_state()
            .map_err(|error| Status::internal(error.to_string()))?;
        let database = database::Database::open(&self.database_path)
            .map_err(|error| Status::internal(error.to_string()))?;
        let entries = database
            .playlist_media_paths(playlist_id)
            .map_err(|error| Status::not_found(error.to_string()))?;
        let (resume_entry_id, resume_position_ms) = resume_state
            .filter(|state| state.playlist_id == Some(playlist_id))
            .map(|state| (state.playlist_entry_id, state.position_ms))
            .unwrap_or((None, 0));
        let message = self
            .player
            .play_playlist(
                playlist_id,
                entries,
                resume_entry_id,
                resume_position_ms,
                &self.resume_mode,
            )
            .map_err(|error| Status::failed_precondition(error.to_string()))?;
        self.save_resume_state()
            .map_err(|error| Status::internal(error.to_string()))?;
        Ok(Response::new(CommandResponse {
            success: true,
            message,
        }))
    }

    async fn get_player_state(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<PlayerState>, Status> {
        Ok(Response::new(PlayerState {
            status: self.player.state().to_string(),
            media_path: self.player.media_path(),
            position_ms: self.player.position_ms(),
            duration_ms: 0,
            playlist_id: self.player.playlist_id().unwrap_or_default() as u64,
        }))
    }

    async fn search_media(
        &self,
        request: Request<SearchMediaRequest>,
    ) -> Result<Response<SearchMediaResponse>, Status> {
        let database = database::Database::open(&self.database_path)
            .map_err(|error| Status::internal(error.to_string()))?;
        let items = database
            .search_media(&request.into_inner().query)
            .map_err(|error| Status::internal(error.to_string()))?
            .into_iter()
            .map(|media| carnine::MediaItem {
                id: media.id as u64,
                source_id: media.source_id as u64,
                path: media.path,
                title: media.title,
                artist: media.artist,
                duration_ms: media.duration_ms,
                status: media.status,
            })
            .collect();
        Ok(Response::new(SearchMediaResponse { items }))
    }

    async fn rescan_media(
        &self,
        _request: Request<RescanMediaRequest>,
    ) -> Result<Response<Self::RescanMediaStream>, Status> {
        let events = self
            .scan_events()
            .map_err(|error| Status::internal(error.to_string()))?;
        for event in &events {
            let _ = self.library_events.send(event.clone());
        }
        let events = events.into_iter().map(Ok).collect::<Vec<_>>();
        Ok(Response::new(tokio_stream::iter(events)))
    }

    async fn stream_library_events(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<Self::StreamLibraryEventsStream>, Status> {
        let updates = tokio_stream::wrappers::BroadcastStream::new(self.library_events.subscribe())
            .filter_map(|event| async move { event.ok().map(Ok) });
        Ok(Response::new(Box::pin(updates)))
    }

    async fn create_playlist(
        &self,
        request: Request<CreatePlaylistRequest>,
    ) -> Result<Response<Playlist>, Status> {
        let name = request.into_inner().name;
        if name.trim().is_empty() {
            return Err(Status::invalid_argument("playlist name must not be empty"));
        }
        let database = database::Database::open(&self.database_path)
            .map_err(|error| Status::internal(error.to_string()))?;
        let id = database
            .create_playlist(&name)
            .map_err(|error| Status::already_exists(error.to_string()))?;
        Ok(Response::new(Playlist {
            id: id as u64,
            name,
            entries: Vec::new(),
        }))
    }

    async fn list_playlists(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<ListPlaylistsResponse>, Status> {
        let database = database::Database::open(&self.database_path)
            .map_err(|error| Status::internal(error.to_string()))?;
        let playlists = database
            .playlists()
            .map_err(|error| Status::internal(error.to_string()))?
            .into_iter()
            .map(|playlist| Playlist {
                id: playlist.id as u64,
                name: playlist.name,
                entries: Vec::new(),
            })
            .collect();
        Ok(Response::new(ListPlaylistsResponse { playlists }))
    }

    async fn add_playlist_entry(
        &self,
        request: Request<AddPlaylistEntryRequest>,
    ) -> Result<Response<PlaylistEntry>, Status> {
        let request = request.into_inner();
        let database = database::Database::open(&self.database_path)
            .map_err(|error| Status::internal(error.to_string()))?;
        let id = database
            .add_playlist_entry(request.playlist_id as i64, request.media_id as i64)
            .map_err(|error| Status::invalid_argument(error.to_string()))?;
        let entries = database
            .playlist_entries(request.playlist_id as i64)
            .map_err(|error| Status::internal(error.to_string()))?;
        let entry = entries
            .into_iter()
            .find(|entry| entry.id == id)
            .ok_or_else(|| Status::internal("created playlist entry was not found"))?;
        Ok(Response::new(PlaylistEntry {
            id: entry.id as u64,
            playlist_id: entry.playlist_id as u64,
            media_id: entry.media_id as u64,
            position: entry.position as u64,
        }))
    }

    async fn get_playlist(
        &self,
        request: Request<GetPlaylistRequest>,
    ) -> Result<Response<Playlist>, Status> {
        let playlist_id = request.into_inner().playlist_id as i64;
        let database = database::Database::open(&self.database_path)
            .map_err(|error| Status::internal(error.to_string()))?;
        let name = database
            .playlist_name(playlist_id)
            .map_err(|error| Status::not_found(error.to_string()))?;
        let entries = database
            .playlist_entries(playlist_id)
            .map_err(|error| Status::internal(error.to_string()))?
            .into_iter()
            .map(|entry| PlaylistEntry {
                id: entry.id as u64,
                playlist_id: entry.playlist_id as u64,
                media_id: entry.media_id as u64,
                position: entry.position as u64,
            })
            .collect();
        Ok(Response::new(Playlist {
            id: playlist_id as u64,
            name,
            entries,
        }))
    }

    async fn stream_player_events(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<Self::StreamPlayerEventsStream>, Status> {
        let snapshot = tokio_stream::once(Ok(self.player.snapshot_event()));
        let command_updates =
            tokio_stream::wrappers::BroadcastStream::new(self.player.subscribe_events())
                .filter_map(|event| async move { event.ok().map(Ok) });
        let player = Arc::clone(&self.player);
        let position_updates = tokio_stream::wrappers::IntervalStream::new(tokio::time::interval(
            Duration::from_secs(1),
        ))
        .filter_map(move |_| {
            let player = Arc::clone(&player);
            async move { (player.state() == "playing").then(|| Ok(player.position_event())) }
        });
        let updates = tokio_stream::StreamExt::merge(command_updates, position_updates);
        Ok(Response::new(Box::pin(snapshot.chain(updates))))
    }
}

impl MediaServiceImpl {
    fn command(
        &self,
        command: &str,
        parameters: String,
    ) -> Result<Response<CommandResponse>, Status> {
        if command == "stop" {
            self.save_resume_state()
                .map_err(|error| Status::internal(error.to_string()))?;
        }
        let message = self
            .player
            .execute(command, &parameters)
            .map_err(|error| Status::failed_precondition(error.to_string()))?;
        Ok(Response::new(CommandResponse {
            success: true,
            message,
        }))
    }
}

#[tonic::async_trait]
impl AudioService for AudioServiceImpl {
    type StreamAudioEventsStream =
        Pin<Box<dyn futures_util::Stream<Item = Result<AudioEvent, Status>> + Send>>;

    async fn get_service_version(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<ServiceVersion>, Status> {
        Ok(Response::new(ServiceVersion {
            major: 0,
            minor: 1,
            patch: 0,
        }))
    }

    async fn stream_audio_events(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<Self::StreamAudioEventsStream>, Status> {
        let snapshot = tokio_stream::once(Ok(AudioEvent {
            event: "audio_ready".to_string(),
            message: format!("audio backend {} on {}", self.backend, self.device),
        }));
        let updates = tokio_stream::wrappers::BroadcastStream::new(self.events.subscribe())
            .filter_map(|event| async move { event.ok().map(Ok) });
        Ok(Response::new(Box::pin(snapshot.chain(updates))))
    }
}

fn configuration_to_proto(configuration: &config::Config) -> Configuration {
    Configuration {
        server_address: configuration.server.address.clone(),
        database_path: configuration.media.database_path.display().to_string(),
        media_folders: configuration
            .media
            .folders
            .iter()
            .map(|path| path.display().to_string())
            .collect(),
        supported_formats: configuration.media.supported_formats.clone(),
        rescan_on_start: configuration.media.rescan_on_start,
        resume_mode: configuration.media.resume_mode.clone(),
        audio_backend: configuration.audio.backend.clone(),
        audio_device: configuration.audio.device.clone(),
        sample_rate: configuration.audio.sample_rate,
        channels: u32::from(configuration.audio.channels),
        navigation_interrupt: configuration.audio.navigation_interrupt.clone(),
        log_directory: configuration.logging.directory.display().to_string(),
        log_level: configuration.logging.level.clone(),
    }
}

fn configuration_from_proto(configuration: &Configuration) -> Result<config::Config> {
    if configuration.server_address.trim().is_empty()
        || configuration.database_path.trim().is_empty()
        || configuration.audio_backend.trim().is_empty()
        || configuration.audio_device.trim().is_empty()
        || configuration.sample_rate == 0
        || configuration.channels == 0
    {
        bail!("configuration contains an empty or invalid required value");
    }

    let channels = u16::try_from(configuration.channels)
        .context("audio channels exceed the supported range")?;
    let configuration = config::Config {
        server: config::ServerConfig {
            address: configuration.server_address.clone(),
        },
        media: config::MediaConfig {
            database_path: PathBuf::from(&configuration.database_path),
            folders: configuration
                .media_folders
                .iter()
                .map(PathBuf::from)
                .collect(),
            supported_formats: configuration.supported_formats.clone(),
            rescan_on_start: configuration.rescan_on_start,
            resume_mode: configuration.resume_mode.clone(),
        },
        audio: config::AudioConfig {
            backend: configuration.audio_backend.clone(),
            device: configuration.audio_device.clone(),
            sample_rate: configuration.sample_rate,
            channels,
            navigation_interrupt: configuration.navigation_interrupt.clone(),
        },
        logging: config::LoggingConfig {
            directory: PathBuf::from(&configuration.log_directory),
            level: configuration.log_level.clone(),
        },
    };
    configuration.validate()?;
    Ok(configuration)
}

#[tokio::main]
async fn main() -> Result<()> {
    let (configuration, configuration_path) = config::Config::load()?;
    std::fs::create_dir_all(&configuration.logging.directory).with_context(|| {
        format!(
            "cannot create log directory {}; for development set CARNINE_LOG_DIRECTORY to a writable path such as /tmp/carnine-log",
            configuration.logging.directory.display()
        )
    })?;
    let file_appender = rolling::never(&configuration.logging.directory, "backend.log");
    let (non_blocking, _guard) = tracing_appender::non_blocking(file_appender);

    let console_layer = tracing_subscriber::fmt::layer()
        .with_writer(std::io::stdout)
        .with_ansi(true)
        .with_target(false)
        .compact();

    let file_layer = tracing_subscriber::fmt::layer()
        .with_writer(non_blocking)
        .with_ansi(false)
        .with_target(false)
        .compact();

    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::new(
            &configuration.logging.level,
        ))
        .with(console_layer)
        .with(file_layer)
        .init();

    info!(
        "carnine backend bootstrap started; config={}",
        configuration_path.display()
    );

    if let Some(parent) = configuration.media.database_path.parent() {
        std::fs::create_dir_all(parent).with_context(|| {
            format!(
                "cannot create database directory {}; for development use a writable database path",
                parent.display()
            )
        })?;
    }
    let _database =
        database::Database::open(&configuration.media.database_path).with_context(|| {
            format!(
                "cannot open database {}; check its permissions or use a writable development path",
                configuration.media.database_path.display()
            )
        })?;
    let addr = configuration.server.address.parse()?;
    let carnine_service = CarnineServiceImpl::default();
    let media_service = MediaServiceImpl::new(
        &configuration.audio,
        configuration.media.database_path.clone(),
        configuration.media.folders.clone(),
        configuration.media.supported_formats.clone(),
        configuration.media.resume_mode.clone(),
    );
    media_service.restore_resume_state()?;
    storage_events::spawn(Arc::new(media_service.clone()));
    let media_player = Arc::clone(&media_service.player);
    let config_service = ConfigServiceImpl::new(configuration.clone(), configuration_path);

    info!("Starting gRPC server on {}", addr);
    Server::builder()
        .add_service(CarnineServiceServer::new(carnine_service))
        .add_service(MediaServiceServer::new(media_service.clone()))
        .add_service(AudioServiceServer::new(AudioServiceImpl::new(
            &configuration.audio,
        )))
        .add_service(ConfigServiceServer::new(config_service))
        .serve_with_shutdown(addr, shutdown_signal())
        .await?;

    media_service.save_resume_state()?;
    media_player.shutdown()?;
    warn!("gRPC server stopped");
    Ok(())
}

async fn shutdown_signal() {
    #[cfg(unix)]
    {
        use tokio::signal::unix::{signal, SignalKind};

        let mut terminate = signal(SignalKind::terminate()).expect("install SIGTERM handler");
        tokio::select! {
            _ = tokio::signal::ctrl_c() => {}
            _ = terminate.recv() => {}
        }
    }

    #[cfg(not(unix))]
    {
        tokio::signal::ctrl_c()
            .await
            .expect("install Ctrl+C handler");
    }
}

#[cfg(test)]
mod tests {
    use super::{configuration_from_proto, configuration_to_proto, ConfigServiceImpl};
    use super::{AudioServiceImpl, MediaServiceImpl};
    use crate::audio_engine::{AudioEngine, Playback};
    use crate::carnine::{
        audio_service_server::AudioService, config_service_server::ConfigService,
        media_service_server::MediaService, Empty, RescanMediaRequest,
    };
    use crate::config;
    use crate::database;
    use crate::media_player::MediaPlayer;
    use anyhow::Result;
    use std::path::PathBuf;
    use std::time::Duration;
    use tokio_stream::StreamExt;
    use tonic::Request;

    struct FakePlayback;

    impl Playback for FakePlayback {
        fn pause(&self) -> Result<()> {
            Ok(())
        }

        fn resume(&self) -> Result<()> {
            Ok(())
        }

        fn stop(self: Box<Self>) -> Result<()> {
            Ok(())
        }
    }

    struct FakeAudioEngine;

    impl AudioEngine for FakeAudioEngine {
        fn start(&self, _input_path: &str) -> Result<Box<dyn Playback>> {
            Ok(Box::new(FakePlayback))
        }
    }

    fn test_configuration() -> config::Config {
        config::Config {
            server: config::ServerConfig {
                address: "[::1]:50051".to_string(),
            },
            media: config::MediaConfig {
                database_path: PathBuf::from("/tmp/media.sqlite3"),
                folders: vec![PathBuf::from("/tmp/media")],
                supported_formats: vec!["mp3".to_string(), "flac".to_string()],
                rescan_on_start: true,
                resume_mode: "restore_paused".to_string(),
            },
            audio: config::AudioConfig {
                backend: "alsa".to_string(),
                device: "plughw:1,0".to_string(),
                sample_rate: 44_100,
                channels: 2,
                navigation_interrupt: "pause_music".to_string(),
            },
            logging: config::LoggingConfig {
                directory: PathBuf::from("/tmp/carnine-logs"),
                level: "info".to_string(),
            },
        }
    }

    #[test]
    fn configuration_proto_roundtrip_preserves_values() {
        let original = test_configuration();
        let proto = configuration_to_proto(&original);
        let restored = configuration_from_proto(&proto).expect("configuration should be valid");

        assert_eq!(restored.server.address, original.server.address);
        assert_eq!(restored.media.database_path, original.media.database_path);
        assert_eq!(restored.media.folders, original.media.folders);
        assert_eq!(
            restored.media.supported_formats,
            original.media.supported_formats
        );
        assert_eq!(
            restored.media.rescan_on_start,
            original.media.rescan_on_start
        );
        assert_eq!(restored.media.resume_mode, original.media.resume_mode);
        assert_eq!(restored.audio.backend, original.audio.backend);
        assert_eq!(restored.audio.device, original.audio.device);
        assert_eq!(restored.audio.sample_rate, original.audio.sample_rate);
        assert_eq!(restored.audio.channels, original.audio.channels);
        assert_eq!(
            restored.audio.navigation_interrupt,
            original.audio.navigation_interrupt
        );
        assert_eq!(restored.logging.directory, original.logging.directory);
        assert_eq!(restored.logging.level, original.logging.level);
    }

    #[test]
    fn configuration_from_proto_rejects_invalid_required_values() {
        let mut configuration = configuration_to_proto(&test_configuration());
        configuration.sample_rate = 0;

        assert!(configuration_from_proto(&configuration).is_err());
    }

    #[tokio::test]
    async fn update_configuration_writes_atomically_and_requires_restart() {
        let path =
            std::env::temp_dir().join(format!("carnine-config-test-{}.toml", std::process::id()));
        let _ = std::fs::remove_file(&path);
        let service = ConfigServiceImpl::new(test_configuration(), path.clone());
        let response = service
            .update_configuration(Request::new(super::UpdateConfigurationRequest {
                configuration: Some(configuration_to_proto(&test_configuration())),
            }))
            .await
            .expect("configuration update should succeed")
            .into_inner();

        assert!(response.success);
        assert!(response.restart_required);
        assert!(response.message.contains("restart required"));
        assert!(path.is_file());
        let saved = std::fs::read_to_string(&path).expect("configuration should be saved");
        let saved_configuration: config::Config =
            toml::from_str(&saved).expect("saved configuration should be valid TOML");
        assert_eq!(saved_configuration.audio.device, "plughw:1,0");
        let _ = std::fs::remove_file(path);
    }

    #[tokio::test]
    async fn rescan_service_emits_progress_events() {
        let folder = std::env::temp_dir().join(format!(
            "carnine-service-rescan-test-{}",
            std::process::id()
        ));
        let _ = std::fs::remove_dir_all(&folder);
        std::fs::create_dir_all(&folder).expect("media folder should be created");
        let media_path = folder.join("service-song.mp3");
        std::fs::write(&media_path, b"test").expect("media file should be created");
        let database_path = folder.join("media.sqlite3");
        let service = MediaServiceImpl::new(
            &config::AudioConfig {
                backend: "alsa".to_string(),
                device: "default".to_string(),
                sample_rate: 44_100,
                channels: 2,
                navigation_interrupt: "pause_music".to_string(),
            },
            database_path,
            vec![folder.clone()],
            vec!["mp3".to_string()],
            "restore_paused".to_string(),
        );
        let response = service
            .rescan_media(Request::new(RescanMediaRequest {}))
            .await
            .expect("rescan should succeed");
        let events = response.into_inner().collect::<Vec<_>>().await;

        assert_eq!(events.len(), 3);
        assert_eq!(
            events[0].as_ref().expect("start event").event,
            "scan_started"
        );
        assert_eq!(
            events[1].as_ref().expect("progress event").event,
            "progress"
        );
        assert_eq!(events[1].as_ref().expect("progress event").imported, 1);
        assert_eq!(
            events[2].as_ref().expect("complete event").event,
            "scan_completed"
        );
        let _ = std::fs::remove_dir_all(folder);
    }

    #[tokio::test]
    async fn player_event_stream_starts_with_snapshot() {
        use tokio_stream::StreamExt;

        let service = MediaServiceImpl::new(
            &config::AudioConfig {
                backend: "alsa".to_string(),
                device: "default".to_string(),
                sample_rate: 44_100,
                channels: 2,
                navigation_interrupt: "pause_music".to_string(),
            },
            std::env::temp_dir().join(format!(
                "carnine-player-events-{}.sqlite3",
                std::process::id()
            )),
            Vec::new(),
            Vec::new(),
            "restore_paused".to_string(),
        );
        let mut events = service
            .stream_player_events(Request::new(super::Empty {}))
            .await
            .expect("player events should open")
            .into_inner();
        let event = events
            .next()
            .await
            .expect("snapshot should exist")
            .expect("snapshot should be valid");

        assert_eq!(event.event, "snapshot");
        assert_eq!(event.state.expect("snapshot state").status, "stopped");

        let _ = service.player.execute("invalid", "");
        let event = events
            .next()
            .await
            .expect("error event should arrive")
            .expect("error event should be valid");

        assert_eq!(event.event, "error");
        assert!(event.message.contains("unknown media command"));
    }

    #[tokio::test]
    async fn player_event_stream_emits_position_updates_while_playing() {
        let player = MediaPlayer::with_engine(Box::new(FakeAudioEngine));
        let service = MediaServiceImpl::with_player(
            player,
            std::env::temp_dir().join(format!(
                "carnine-position-events-{}.sqlite3",
                std::process::id()
            )),
            Vec::new(),
            Vec::new(),
            "restore_paused".to_string(),
        );
        let mut events = service
            .stream_player_events(Request::new(Empty {}))
            .await
            .expect("player events should open")
            .into_inner();
        let snapshot = events
            .next()
            .await
            .expect("snapshot should exist")
            .expect("snapshot should be valid");
        assert_eq!(snapshot.event, "snapshot");

        service
            .player
            .play_playlist(
                1,
                vec![(1, "fake-audio.mp3".to_string())],
                None,
                0,
                "auto-play",
            )
            .expect("fake playback should start");

        let started = events
            .next()
            .await
            .expect("start event should arrive")
            .expect("start event should be valid");
        assert_eq!(started.event, "playback_started");

        let first = tokio::time::timeout(Duration::from_secs(2), events.next())
            .await
            .expect("first position event should arrive")
            .expect("position stream should remain open")
            .expect("first position event should be valid");
        let second = tokio::time::timeout(Duration::from_secs(2), events.next())
            .await
            .expect("second position event should arrive")
            .expect("position stream should remain open")
            .expect("second position event should be valid");

        assert_eq!(first.event, "position_changed");
        assert_eq!(second.event, "position_changed");
        assert!(
            second.state.expect("second state should exist").position_ms
                >= first.state.expect("first state should exist").position_ms
        );
    }

    #[test]
    fn restart_current_track_preserves_queue_position() {
        let player = MediaPlayer::with_engine(Box::new(FakeAudioEngine));
        player
            .play_playlist(
                1,
                vec![
                    (10, "first.wav".to_string()),
                    (11, "second.wav".to_string()),
                ],
                Some(11),
                0,
                "auto-play",
            )
            .expect("fake playback should start");

        let result = player.execute("restart", "");

        assert!(result.is_ok());
        assert_eq!(player.playlist_id(), Some(1));
        assert_eq!(player.playlist_entry_id(), Some(11));
        assert_eq!(player.media_path(), "second.wav");
        assert_eq!(player.position_ms(), 0);
        assert_eq!(player.state(), "playing");
    }

    #[test]
    fn direct_track_play_clears_previous_playlist_context() {
        let player = MediaPlayer::with_engine(Box::new(FakeAudioEngine));
        player
            .play_playlist(
                1,
                vec![(10, "playlist.wav".to_string())],
                None,
                0,
                "restore_paused",
            )
            .expect("playlist should load");
        player.execute("stop", "").expect("playback should stop");
        let path = std::env::temp_dir().join(format!("carnine-direct-{}.wav", std::process::id()));
        std::fs::write(&path, b"fake").expect("test media should be created");

        player
            .execute("play", &path.to_string_lossy())
            .expect("direct playback should start");

        assert_eq!(player.playlist_id(), None);
        let _ = std::fs::remove_file(path);
    }

    #[test]
    fn queue_entry_playback_switches_track_without_changing_queue() {
        let player = MediaPlayer::with_engine(Box::new(FakeAudioEngine));
        player
            .play_playlist(
                1,
                vec![
                    (10, "first.wav".to_string()),
                    (11, "second.wav".to_string()),
                    (12, "third.wav".to_string()),
                ],
                Some(10),
                0,
                "auto-play",
            )
            .expect("fake playback should start");

        player
            .execute("queue-entry", "2")
            .expect("queue entry should start");

        assert_eq!(player.playlist_id(), Some(1));
        assert_eq!(player.playlist_entry_id(), Some(12));
        assert_eq!(player.media_path(), "third.wav");
        assert_eq!(player.position_ms(), 0);
        assert_eq!(player.state(), "playing");
    }

    #[tokio::test]
    async fn library_event_stream_receives_rescan_events() {
        let folder =
            std::env::temp_dir().join(format!("carnine-library-events-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&folder);
        std::fs::create_dir_all(&folder).expect("media folder should be created");
        let service = MediaServiceImpl::new(
            &test_configuration().audio,
            folder.join("media.sqlite3"),
            vec![folder.clone()],
            vec!["mp3".to_string()],
            "restore_paused".to_string(),
        );
        let mut events = service
            .stream_library_events(Request::new(Empty {}))
            .await
            .expect("library events should open")
            .into_inner();

        service
            .rescan_media(Request::new(RescanMediaRequest {}))
            .await
            .expect("rescan should succeed");

        let event = events
            .next()
            .await
            .expect("scan event should arrive")
            .expect("scan event should be valid");
        assert_eq!(event.event, "scan_started");
        let _ = std::fs::remove_dir_all(folder);
    }

    #[tokio::test]
    async fn audio_event_stream_starts_with_status_and_receives_updates() {
        let service = AudioServiceImpl::new(&test_configuration().audio);
        let mut events = service
            .stream_audio_events(Request::new(Empty {}))
            .await
            .expect("audio events should open")
            .into_inner();

        let snapshot = events
            .next()
            .await
            .expect("audio snapshot should arrive")
            .expect("audio snapshot should be valid");
        assert_eq!(snapshot.event, "audio_ready");
        assert!(snapshot.message.contains("plughw:1,0"));

        service.publish("device_changed", "audio device changed");
        let event = events
            .next()
            .await
            .expect("audio update should arrive")
            .expect("audio update should be valid");
        assert_eq!(event.event, "device_changed");
    }

    #[test]
    fn service_persists_and_restores_playlist_resume_context() {
        let database_path = std::env::temp_dir().join(format!(
            "carnine-resume-service-{}.sqlite3",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&database_path);
        let database = database::Database::open(&database_path).expect("database should open");
        let source_id = database
            .upsert_source("/music", "AVAILABLE")
            .expect("source should save");
        let media_id = database
            .upsert_media(&database::MediaRecord {
                id: 0,
                source_id,
                path: "/music/last.mp3".to_string(),
                title: "Last".to_string(),
                artist: "Artist".to_string(),
                duration_ms: 100_000,
                status: "AVAILABLE".to_string(),
            })
            .expect("media should save");
        let playlist_id = database
            .create_playlist("Resume")
            .expect("playlist should save");
        let playlist_entry_id = database
            .add_playlist_entry(playlist_id, media_id)
            .expect("playlist entry should save");
        drop(database);
        let audio_config = config::AudioConfig {
            backend: "alsa".to_string(),
            device: "default".to_string(),
            sample_rate: 44_100,
            channels: 2,
            navigation_interrupt: "pause_music".to_string(),
        };
        let service = MediaServiceImpl::new(
            &audio_config,
            database_path.clone(),
            Vec::new(),
            Vec::new(),
            "restore_paused".to_string(),
        );
        service
            .player
            .play_playlist(
                playlist_id,
                vec![(playlist_entry_id, "/music/last.mp3".to_string())],
                Some(playlist_entry_id),
                12_345,
                "restore_paused",
            )
            .expect("resume context should load");
        service
            .save_resume_state()
            .expect("resume context should save");

        let restored_service = MediaServiceImpl::new(
            &audio_config,
            database_path.clone(),
            Vec::new(),
            Vec::new(),
            "restore_paused".to_string(),
        );
        restored_service
            .restore_resume_state()
            .expect("resume context should restore");

        assert_eq!(restored_service.player.playlist_id(), Some(playlist_id));
        assert_eq!(
            restored_service.player.playlist_entry_id(),
            Some(playlist_entry_id)
        );
        assert_eq!(restored_service.player.position_ms(), 12_345);
        assert_eq!(restored_service.player.state(), "paused");
        let _ = std::fs::remove_file(database_path);
    }
}

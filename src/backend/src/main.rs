// Every gRPC handler returns tonic's `Status`, which is 176 bytes, so clippy's
// result_large_err fires across the whole service surface. Boxing it would only
// move the size into each call site, and the type is the API's, not ours.
#![allow(clippy::result_large_err)]

use std::pin::Pin;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::Duration;
use std::{fs, path::PathBuf, sync::Mutex};

use anyhow::{bail, Context, Result};
use futures_util::StreamExt;
use tokio::sync::broadcast;
use tokio::sync::oneshot;
use tonic::{transport::Server, Request, Response, Status};
use tracing::{debug, error, info, warn};
use tracing_appender::rolling;
use tracing_subscriber::prelude::*;

pub mod carnine {
    tonic::include_proto!("carnine");
}

mod audio_engine;
mod audio_mixer;
mod audio_source;
mod audio_volume;
mod config;
mod cpal_audio_engine;
mod database;
mod media_player;
mod navigation;
mod server_transport;
mod storage_events;
mod system_metrics;

use carnine::get_cover_art_request::Target as CoverArtTarget;
use carnine::{
    audio_service_server::{AudioService, AudioServiceServer},
    carnine_service_server::{CarnineService, CarnineServiceServer},
    config_service_server::{ConfigService, ConfigServiceServer},
    media_service_server::{MediaService, MediaServiceServer},
    AddPlaylistEntryRequest, AudioEvent, AudioEventType, CanData, CanDataRequest, CanDataResponse,
    CommandResponse, Configuration, ConfigurationResponse, CreatePlaylistRequest, Empty,
    GetCoverArtRequest, GetCoverArtResponse, GetPlaylistRequest, ImportMusicVolumeRequest,
    LibraryEvent, LibraryEventType, ListPlaylistsResponse, PlayPlaylistRequest,
    PlayQueueEntryRequest, PlayRequest, PlayerEvent, PlayerEventType, PlayerState, Playlist,
    PlaylistEntry, RepeatMode, RescanMediaRequest, SearchMediaRequest, SearchMediaResponse,
    ServiceVersion, SetRepeatModeRequest, SetShuffleModeRequest, SetVolumeRequest, SystemMetrics,
    UiState, UpdateConfigurationRequest, VolumeResponse,
};

#[derive(Debug, Default)]
pub struct SystemServiceImpl {
    metrics: Arc<system_metrics::SystemMetricsHandle>,
    database_path: PathBuf,
}

/// Page names are identifiers like "maps"; anything longer is not one.
const MAX_UI_PAGE_NAME_LEN: usize = 64;

impl SystemServiceImpl {
    pub fn new(metrics: Arc<system_metrics::SystemMetricsHandle>, database_path: PathBuf) -> Self {
        Self {
            metrics,
            database_path,
        }
    }
}

fn service_version() -> ServiceVersion {
    let parts: Vec<u32> = env!("CARNINE_VERSION")
        .split('.')
        .map(|part| {
            part.parse()
                .expect("CARNINE_VERSION must be numeric semver")
        })
        .collect();
    assert!(
        parts.len() == 3,
        "CARNINE_VERSION must be major.minor.patch"
    );
    ServiceVersion {
        major: parts[0],
        minor: parts[1],
        patch: parts[2],
    }
}

#[tonic::async_trait]
impl carnine::system_service_server::SystemService for SystemServiceImpl {
    type StreamSystemMetricsStream =
        Pin<Box<dyn tokio_stream::Stream<Item = Result<SystemMetrics, Status>> + Send + 'static>>;

    async fn report_ui_ready(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<CommandResponse>, Status> {
        info!("Carnine UI reported ready");
        Ok(Response::new(CommandResponse {
            success: true,
            message: "UI ready".to_string(),
        }))
    }

    async fn get_system_metrics(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<SystemMetrics>, Status> {
        Ok(Response::new(self.metrics.latest()))
    }

    async fn stream_system_metrics(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<Self::StreamSystemMetricsStream>, Status> {
        info!("system metrics stream opened");
        // Open with the cached snapshot so a client does not have to wait a
        // whole sampling interval for its first value.
        let snapshot = tokio_stream::once(Ok(self.metrics.latest()));
        let updates = tokio_stream::wrappers::BroadcastStream::new(self.metrics.subscribe())
            .filter_map(|metrics| async move { metrics.ok().map(Ok) });
        Ok(Response::new(Box::pin(snapshot.chain(updates))))
    }

    async fn get_ui_state(&self, _request: Request<Empty>) -> Result<Response<UiState>, Status> {
        let last_page = database::Database::open(&self.database_path)
            .and_then(|database| database.load_last_page())
            .map_err(|error| {
                error!(error = %error, "loading UI state failed");
                Status::internal(error.to_string())
            })?;
        debug!(last_page = %last_page, "UI state loaded");
        Ok(Response::new(UiState { last_page }))
    }

    async fn save_ui_state(
        &self,
        request: Request<UiState>,
    ) -> Result<Response<CommandResponse>, Status> {
        let last_page = request.into_inner().last_page;
        info!(last_page = %last_page, "saving UI state requested");
        if last_page.len() > MAX_UI_PAGE_NAME_LEN {
            return Err(Status::invalid_argument(format!(
                "page name longer than {MAX_UI_PAGE_NAME_LEN} bytes"
            )));
        }
        database::Database::open(&self.database_path)
            .and_then(|database| database.save_last_page(&last_page))
            .map_err(|error| {
                error!(error = %error, "saving UI state failed");
                Status::internal(error.to_string())
            })?;
        info!(last_page = %last_page, "UI state saved");
        Ok(Response::new(CommandResponse {
            success: true,
            message: "UI state saved".to_string(),
        }))
    }
}

use database::ResumeState;
use media_player::MediaPlayer;

#[derive(Debug, Default)]
pub struct CarnineServiceImpl;

fn saves_resume_state(event: i32) -> bool {
    [
        PlayerEventType::PlayerPlaybackStarted,
        PlayerEventType::PlayerTrackChanged,
        PlayerEventType::PlayerQueueFinished,
    ]
    .iter()
    .any(|kind| *kind as i32 == event)
}

#[derive(Clone)]
pub struct MediaServiceImpl {
    player: Arc<MediaPlayer>,
    database_path: PathBuf,
    media_folders: Vec<PathBuf>,
    supported_formats: Vec<String>,
    resume_mode: String,
    cover_cache_dir: PathBuf,
    library_events: broadcast::Sender<LibraryEvent>,
    next_scan_id: Arc<AtomicU64>,
    /// The volume waiting for the user's "Uebernehmen", kept so that a client
    /// which connects later still learns about it. The event is broadcast once,
    /// at the moment the volume is found - on the Pi that happens while the
    /// service starts, seconds before the UI is up, and a live-only stream
    /// would drop it and never offer the import.
    pending_music_volume: Arc<Mutex<Option<LibraryEvent>>>,
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
    fn from_player(
        player: MediaPlayer,
        database_path: PathBuf,
        media_folders: Vec<PathBuf>,
        supported_formats: Vec<String>,
        resume_mode: String,
        cover_cache_dir: PathBuf,
    ) -> Self {
        let (library_events, _) = broadcast::channel(64);
        let lookup_database = database_path.clone();
        player.set_duration_lookup(Box::new(move |path| {
            database::Database::open(&lookup_database)
                .and_then(|database| database.duration_by_path(path))
                .unwrap_or_else(|error| {
                    warn!(%error, path, "track duration lookup failed");
                    None
                })
        }));
        Self {
            player: Arc::new(player),
            database_path,
            media_folders,
            supported_formats,
            resume_mode,
            cover_cache_dir,
            library_events,
            next_scan_id: Arc::new(AtomicU64::new(1)),
            pending_music_volume: Arc::new(Mutex::new(None)),
        }
    }

    fn new_runtime(
        database_path: PathBuf,
        media_folders: Vec<PathBuf>,
        supported_formats: Vec<String>,
        resume_mode: String,
        cover_cache_dir: PathBuf,
    ) -> Result<Self> {
        Ok(Self::from_player(
            MediaPlayer::new()?,
            database_path,
            media_folders,
            supported_formats,
            resume_mode,
            cover_cache_dir,
        ))
    }

    #[cfg(test)]
    fn with_player(
        player: MediaPlayer,
        database_path: PathBuf,
        media_folders: Vec<PathBuf>,
        supported_formats: Vec<String>,
        resume_mode: String,
        cover_cache_dir: PathBuf,
    ) -> Self {
        Self::from_player(
            player,
            database_path,
            media_folders,
            supported_formats,
            resume_mode,
            cover_cache_dir,
        )
    }

    fn save_resume_state(&self) -> anyhow::Result<()> {
        let database = database::Database::open(&self.database_path)?;
        database.save_resume_state(&ResumeState {
            playlist_id: self.player.playlist_id(),
            playlist_entry_id: self.player.playlist_entry_id(),
            position_ms: self.player.position_ms(),
            resume_mode: self.resume_mode.clone(),
            repeat_mode: self.player.repeat_mode().as_str_name().to_string(),
            shuffle_enabled: self.player.shuffle_enabled(),
        })
    }

    /// Saved at once, not only on stop and SIGTERM: in the car the power goes
    /// without a shutdown. The setting itself has taken effect either way, so
    /// a failed save is logged rather than failing the request.
    fn save_resume_state_after_setting(&self, setting: &str) {
        if let Err(error) = self.save_resume_state() {
            warn!(%error, "failed to save resume state after changing {setting}");
        }
    }

    /// Saves the resume state whenever a track starts, changes or the queue
    /// runs out. Only stop and SIGTERM saved it before, so after a queue ran
    /// to its end the next PlayPlaylist picked up a position from long ago
    /// (#26), and after a power cut the car resumed at an old track.
    fn spawn_resume_saver(&self) {
        let service = self.clone();
        let mut events = self.player.subscribe_events();
        tokio::spawn(async move {
            loop {
                match events.recv().await {
                    Ok(event) if saves_resume_state(event.event) => {
                        if let Err(error) = service.save_resume_state() {
                            warn!(%error, "failed to save resume state after a track change");
                        }
                    }
                    Ok(_) | Err(broadcast::error::RecvError::Lagged(_)) => {}
                    Err(broadcast::error::RecvError::Closed) => break,
                }
            }
        });
    }

    fn restore_resume_state(&self) -> anyhow::Result<()> {
        let database = database::Database::open(&self.database_path)?;
        let Some(state) = database.load_resume_state()? else {
            return Ok(());
        };
        // Before the playlist loads, so that it builds its shuffle order.
        self.player.set_repeat_mode(
            RepeatMode::from_str_name(&state.repeat_mode).unwrap_or(RepeatMode::RepeatOff),
        );
        self.player.set_shuffle_mode(state.shuffle_enabled);
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
            event: LibraryEventType::LibraryScanStarted as i32,
            scan_id,
            ..Default::default()
        }];
        let mut processed = 0_u64;
        let mut imported = 0_u64;
        for folder in &self.media_folders {
            match database.rescan_folder(folder, &self.supported_formats, &self.cover_cache_dir) {
                Ok(count) => {
                    imported += count as u64;
                    processed += count as u64;
                    events.push(LibraryEvent {
                        event: LibraryEventType::LibraryProgress as i32,
                        scan_id,
                        processed,
                        imported,
                        path: folder.display().to_string(),
                        ..Default::default()
                    });
                }
                Err(error) => events.push(LibraryEvent {
                    event: LibraryEventType::LibraryError as i32,
                    scan_id,
                    path: folder.display().to_string(),
                    message: error.to_string(),
                    ..Default::default()
                }),
            }
        }
        events.push(LibraryEvent {
            event: LibraryEventType::LibraryScanCompleted as i32,
            scan_id,
            processed,
            imported,
            ..Default::default()
        });
        Ok(events)
    }

    pub(crate) fn discover_music_volume(
        &self,
        source_label: String,
        source_path: PathBuf,
    ) -> anyhow::Result<()> {
        info!(
            label = %source_label,
            path = %source_path.display(),
            exists = source_path.exists(),
            is_directory = source_path.is_dir(),
            "scanning music volume"
        );
        let matching_files = database::find_audio_files(&source_path, &["mp3".to_string()])?.len();
        info!(
            label = %source_label,
            path = %source_path.display(),
            matching_files,
            "music volume scan completed"
        );
        if matching_files == 0 {
            return Ok(());
        }
        info!(
            label = %source_label,
            path = %source_path.display(),
            matching_files,
            "music found on volume"
        );
        let event = LibraryEvent {
            event: LibraryEventType::LibraryMusicFound as i32,
            scan_id: self.next_scan_id.fetch_add(1, Ordering::Relaxed),
            source_label,
            source_path: source_path.display().to_string(),
            matching_files: matching_files as u64,
            message: format!("found {matching_files} MP3 file(s)"),
            ..Default::default()
        };
        self.remember_pending_music_volume(event.clone());
        let _ = self.library_events.send(event);
        Ok(())
    }

    /// Keeps the offer for clients that connect after it was broadcast, and
    /// replaces an older offer for the same volume.
    fn remember_pending_music_volume(&self, event: LibraryEvent) {
        match self.pending_music_volume.lock() {
            Ok(mut pending) => *pending = Some(event),
            Err(error) => warn!(%error, "pending music volume lock was poisoned"),
        }
    }

    fn take_pending_music_volume(&self) -> Option<LibraryEvent> {
        self.pending_music_volume.lock().ok()?.clone()
    }

    fn clear_pending_music_volume(&self) {
        if let Ok(mut pending) = self.pending_music_volume.lock() {
            *pending = None;
        }
    }

    /// Drops the offer when the volume it points at is gone - a stick pulled
    /// out must not leave a client that connects afterwards offering to import
    /// from it.
    pub(crate) fn forget_absent_music_volumes(&self, present: &[PathBuf]) {
        let Ok(mut pending) = self.pending_music_volume.lock() else {
            return;
        };
        let still_there = pending.as_ref().is_some_and(|event| {
            present
                .iter()
                .any(|path| path.as_os_str().to_string_lossy() == event.source_path)
        });
        if pending.is_some() && !still_there {
            info!("the volume waiting for import is gone; dropping the offer");
            *pending = None;
        }
    }

    fn import_music_volume(&self, source_path: PathBuf) -> anyhow::Result<Vec<LibraryEvent>> {
        if !source_path.is_absolute() || !source_path.starts_with("/media") {
            bail!("music source must be a mounted path below /media");
        }
        let target_root = self
            .media_folders
            .first()
            .context("no internal media folder configured")?;
        let files = database::find_audio_files(&source_path, &["mp3".to_string()])?;
        let scan_id = self.next_scan_id.fetch_add(1, Ordering::Relaxed);
        let mut events = vec![LibraryEvent {
            event: LibraryEventType::LibraryImportStarted as i32,
            scan_id,
            matching_files: files.len() as u64,
            source_path: source_path.display().to_string(),
            ..Default::default()
        }];
        let mut cover_copied_dirs = std::collections::HashSet::new();
        for (index, source_file) in files.iter().enumerate() {
            let relative_path = source_file
                .strip_prefix(&source_path)
                .context("music file is outside the mounted source")?;
            let target_file = target_root.join(relative_path);
            if let Some(parent) = target_file.parent() {
                fs::create_dir_all(parent)?;
            }
            fs::copy(source_file, &target_file)?;

            if let Some(source_dir) = source_file.parent() {
                if cover_copied_dirs.insert(source_dir.to_path_buf()) {
                    if let Some(cover_source) = database::find_folder_cover_image(source_dir) {
                        if let Some(cover_target) = target_file
                            .parent()
                            .and_then(|dir| cover_source.file_name().map(|name| dir.join(name)))
                        {
                            if !cover_target.exists() {
                                fs::copy(&cover_source, &cover_target)?;
                            }
                        }
                    }
                }
            }
            events.push(LibraryEvent {
                event: LibraryEventType::LibraryImportProgress as i32,
                scan_id,
                processed: (index + 1) as u64,
                imported: (index + 1) as u64,
                path: target_file.display().to_string(),
                source_path: source_path.display().to_string(),
                ..Default::default()
            });
        }
        events.push(LibraryEvent {
            event: LibraryEventType::LibraryImportCompleted as i32,
            scan_id,
            processed: files.len() as u64,
            imported: files.len() as u64,
            source_path: source_path.display().to_string(),
            message: format!("imported {} MP3 file(s)", files.len()),
            ..Default::default()
        });
        // The offer has been taken up; a client connecting now must not be
        // asked about the same volume again.
        self.clear_pending_music_volume();
        Ok(events)
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
        let mut updated = configuration_from_proto(&configuration)
            .map_err(|error| Status::invalid_argument(error.to_string()))?;
        updated.navigation = self
            .configuration
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .navigation
            .clone();
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
    volume: Arc<audio_volume::AudioVolume>,
}

impl AudioServiceImpl {
    #[cfg(test)]
    fn new() -> Self {
        let (events, _) = broadcast::channel(32);
        Self::with_events(
            events,
            Arc::new(audio_volume::AudioVolume::new(PathBuf::from(
                "/var/lib/carnine/audio-volume",
            ))),
        )
    }

    fn with_events(
        events: broadcast::Sender<AudioEvent>,
        volume: Arc<audio_volume::AudioVolume>,
    ) -> Self {
        Self { events, volume }
    }

    pub fn publish(&self, event: AudioEventType, message: impl Into<String>) {
        let _ = self.events.send(AudioEvent {
            event: event as i32,
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
    type ImportMusicVolumeStream =
        tokio_stream::Iter<std::vec::IntoIter<Result<LibraryEvent, Status>>>;
    type RescanMediaStream = tokio_stream::Iter<std::vec::IntoIter<Result<LibraryEvent, Status>>>;
    type StreamLibraryEventsStream =
        Pin<Box<dyn futures_util::Stream<Item = Result<LibraryEvent, Status>> + Send>>;

    async fn get_service_version(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<ServiceVersion>, Status> {
        Ok(Response::new(service_version()))
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
        Ok(Response::new(self.player.player_state()))
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
                has_cover_art: media.cover_path.is_some(),
            })
            .collect();
        Ok(Response::new(SearchMediaResponse { items }))
    }

    async fn import_music_volume(
        &self,
        request: Request<ImportMusicVolumeRequest>,
    ) -> Result<Response<Self::ImportMusicVolumeStream>, Status> {
        let source_path = PathBuf::from(request.into_inner().source_path);
        if source_path.as_os_str().is_empty() {
            return Err(Status::invalid_argument("source_path is required"));
        }
        let events = self
            .import_music_volume(source_path)
            .map_err(|error| Status::internal(error.to_string()))?;
        for event in &events {
            let _ = self.library_events.send(event.clone());
        }
        Ok(Response::new(tokio_stream::iter(
            events.into_iter().map(Ok).collect::<Vec<_>>(),
        )))
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
        // A volume found before this client connected is replayed first, the
        // way the player stream opens with its snapshot.
        let pending = tokio_stream::iter(self.take_pending_music_volume().map(Ok));
        Ok(Response::new(Box::pin(pending.chain(updates))))
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
        let _ = self.library_events.send(LibraryEvent {
            event: LibraryEventType::PlaylistCreated as i32,
            playlist_id: id as u64,
            playlist_name: name.clone(),
            ..Default::default()
        });
        Ok(Response::new(Playlist {
            id: id as u64,
            name,
            entries: Vec::new(),
            has_cover_art: false,
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
                has_cover_art: false,
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
        let entry_proto = PlaylistEntry {
            id: entry.id as u64,
            playlist_id: entry.playlist_id as u64,
            media_id: entry.media_id as u64,
            position: entry.position as u64,
        };
        let _ = self.library_events.send(LibraryEvent {
            event: LibraryEventType::PlaylistEntryAdded as i32,
            playlist_id: entry_proto.playlist_id,
            ..Default::default()
        });
        Ok(Response::new(entry_proto))
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
        let has_cover_art = database
            .playlist_cover_path(playlist_id)
            .map_err(|error| Status::internal(error.to_string()))?
            .is_some();
        Ok(Response::new(Playlist {
            id: playlist_id as u64,
            name,
            entries,
            has_cover_art,
        }))
    }

    async fn get_cover_art(
        &self,
        request: Request<GetCoverArtRequest>,
    ) -> Result<Response<GetCoverArtResponse>, Status> {
        let database = database::Database::open(&self.database_path)
            .map_err(|error| Status::internal(error.to_string()))?;
        let cover_path = match request.into_inner().target {
            Some(CoverArtTarget::MediaId(media_id)) => database
                .media_by_id(media_id as i64)
                .map_err(|error| Status::internal(error.to_string()))?
                .and_then(|media| media.cover_path),
            Some(CoverArtTarget::PlaylistId(playlist_id)) => database
                .playlist_cover_path(playlist_id as i64)
                .map_err(|error| Status::internal(error.to_string()))?,
            None => {
                return Err(Status::invalid_argument(
                    "media_id or playlist_id is required",
                ))
            }
        };
        let Some(file_name) = cover_path else {
            return Err(Status::not_found("no cover art available"));
        };
        let file_path = self.cover_cache_dir.join(&file_name);
        let data =
            std::fs::read(&file_path).map_err(|error| Status::internal(error.to_string()))?;
        let mime_type = match file_path
            .extension()
            .and_then(|extension| extension.to_str())
        {
            Some("png") => "image/png",
            _ => "image/jpeg",
        }
        .to_string();
        Ok(Response::new(GetCoverArtResponse { data, mime_type }))
    }

    async fn set_repeat_mode(
        &self,
        request: Request<SetRepeatModeRequest>,
    ) -> Result<Response<CommandResponse>, Status> {
        let mode = request.into_inner().mode();
        self.player.set_repeat_mode(mode);
        self.save_resume_state_after_setting("repeat mode");
        Ok(Response::new(CommandResponse {
            success: true,
            message: format!("repeat mode set to {}", mode.as_str_name()),
        }))
    }

    async fn set_shuffle_mode(
        &self,
        request: Request<SetShuffleModeRequest>,
    ) -> Result<Response<CommandResponse>, Status> {
        let enabled = request.into_inner().enabled;
        self.player.set_shuffle_mode(enabled);
        self.save_resume_state_after_setting("shuffle mode");
        Ok(Response::new(CommandResponse {
            success: true,
            message: format!("shuffle mode set to {enabled}"),
        }))
    }

    async fn stream_player_events(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<Self::StreamPlayerEventsStream>, Status> {
        let snapshot = tokio_stream::once(Ok(self.player.snapshot_event()));
        let command_updates = tokio_stream::wrappers::BroadcastStream::new(
            self.player.subscribe_events(),
        )
        .map(|event| {
            event.map_err(|error| match error {
                tokio_stream::wrappers::errors::BroadcastStreamRecvError::Lagged(count) => {
                    Status::resource_exhausted(format!(
                        "player event subscriber lagged; {count} events were dropped"
                    ))
                }
            })
        });
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
        Ok(Response::new(service_version()))
    }

    async fn stream_audio_events(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<Self::StreamAudioEventsStream>, Status> {
        let snapshot = tokio_stream::once(Ok(AudioEvent {
            event: AudioEventType::AudioReady as i32,
            message: "audio ready".to_string(),
        }));
        let updates = tokio_stream::wrappers::BroadcastStream::new(self.events.subscribe())
            .filter_map(|event| async move { event.ok().map(Ok) });
        Ok(Response::new(Box::pin(snapshot.chain(updates))))
    }

    async fn get_volume(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<VolumeResponse>, Status> {
        Ok(Response::new(VolumeResponse {
            percent: u32::from(self.volume.current()),
        }))
    }

    async fn set_volume(
        &self,
        request: Request<SetVolumeRequest>,
    ) -> Result<Response<VolumeResponse>, Status> {
        let percent = u8::try_from(request.into_inner().percent)
            .map_err(|_| Status::invalid_argument("audio volume must be between 0 and 100"))?;
        let percent = self
            .volume
            .set(percent)
            .map_err(|error| Status::internal(error.to_string()))?;
        Ok(Response::new(VolumeResponse {
            percent: u32::from(percent),
        }))
    }
}

fn configuration_to_proto(configuration: &config::Config) -> Configuration {
    Configuration {
        socket_path: configuration.server.socket_path.display().to_string(),
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
        navigation_interrupt: configuration.audio.navigation_interrupt.clone(),
        log_directory: configuration.logging.directory.display().to_string(),
        log_level: configuration.logging.level.clone(),
        cover_cache_dir: configuration.media.cover_cache_dir.display().to_string(),
        tcp_address: configuration.server.tcp_address.clone().unwrap_or_default(),
        socket_mode: configuration.server.socket_mode.clone().unwrap_or_default(),
        metrics_interval_seconds: configuration.system.metrics_interval_seconds,
        disk_metrics_interval_seconds: configuration.system.disk_metrics_interval_seconds,
        disk_paths: configuration
            .system
            .disk_paths
            .iter()
            .map(|path| path.display().to_string())
            .collect(),
    }
}

fn nonzero_or_default(value: u64, fallback: u64) -> u64 {
    if value == 0 {
        fallback
    } else {
        value
    }
}

fn configuration_from_proto(configuration: &Configuration) -> Result<config::Config> {
    if configuration.socket_path.trim().is_empty() || configuration.database_path.trim().is_empty()
    {
        bail!("configuration contains an empty or invalid required value");
    }

    let tcp_address = configuration.tcp_address.trim();
    let configuration = config::Config {
        server: config::ServerConfig {
            socket_path: PathBuf::from(&configuration.socket_path),
            tcp_address: (!tcp_address.is_empty()).then(|| tcp_address.to_string()),
            socket_mode: {
                let socket_mode = configuration.socket_mode.trim();
                (!socket_mode.is_empty()).then(|| socket_mode.to_string())
            },
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
            cover_cache_dir: PathBuf::from(&configuration.cover_cache_dir),
        },
        audio: config::AudioConfig {
            navigation_interrupt: configuration.navigation_interrupt.clone(),
        },
        logging: config::LoggingConfig {
            directory: PathBuf::from(&configuration.log_directory),
            level: configuration.log_level.clone(),
        },
        system: config::SystemConfig {
            // A client that does not know these fields sends zeros; keep the
            // defaults rather than failing validation on its behalf.
            metrics_interval_seconds: nonzero_or_default(
                configuration.metrics_interval_seconds,
                config::SystemConfig::default().metrics_interval_seconds,
            ),
            disk_metrics_interval_seconds: nonzero_or_default(
                configuration.disk_metrics_interval_seconds,
                config::SystemConfig::default().disk_metrics_interval_seconds,
            ),
            disk_paths: configuration.disk_paths.iter().map(PathBuf::from).collect(),
        },
        // Not part of the Configuration message; update_configuration carries
        // the current section over so saving settings cannot drop it.
        navigation: config::NavigationConfig::default(),
    };
    configuration.validate()?;
    Ok(configuration)
}

/// Usage text for `--help`. It names the environment overrides as well: they
/// decide where the service reads its configuration and where it listens, and
/// nothing else tells an operator that they exist.
const USAGE: &str = "\
carnine-backend - the Carnine gRPC backend service

Usage:
  carnine-backend            Run the service (how systemd starts it)
  carnine-backend --version  Print the release version and build id
  carnine-backend --help     Print this text

Configuration: /etc/carnine/config.toml, then every *.toml in
/etc/carnine/config.d in name order laid over it (a later file wins).
Drop-ins survive a deployment; put device-specific sections there.

Environment overrides (each one wins over the configuration file):
  CARNINE_CONFIG          Path to the configuration file (drop-ins then come
                          from the .d directory beside it)
  CARNINE_LOG_DIRECTORY   Directory for backend.log
  CARNINE_DATABASE_PATH   Path to the SQLite media database
  CARNINE_SOCKET_PATH     Unix domain socket to listen on
  CARNINE_SOCKET_MODE     Octal permissions for that socket, e.g. 0660
  CARNINE_TCP_ADDRESS     Optional TCP fallback address, e.g. 127.0.0.1:50051
";

/// What the command line asked for. No arguments means "run the service",
/// which is how systemd starts it.
#[derive(Debug, PartialEq, Eq)]
enum Invocation {
    Run,
    ShowVersion,
    ShowHelp,
    Unknown(String),
}

fn parse_invocation(arguments: impl IntoIterator<Item = String>) -> Invocation {
    match arguments.into_iter().next() {
        None => Invocation::Run,
        Some(argument) => match argument.as_str() {
            "--version" | "-V" => Invocation::ShowVersion,
            "--help" | "-h" => Invocation::ShowHelp,
            other => Invocation::Unknown(other.to_owned()),
        },
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    // Before anything else: asking the binary what it is must never start a
    // service, open a socket or touch the audio device.
    match parse_invocation(std::env::args().skip(1)) {
        Invocation::Run => {}
        Invocation::ShowVersion => {
            println!(
                "carnine-backend {} (build {})",
                env!("CARNINE_VERSION"),
                env!("CARNINE_BUILD_ID")
            );
            return Ok(());
        }
        Invocation::ShowHelp => {
            print!("{USAGE}");
            return Ok(());
        }
        Invocation::Unknown(argument) => {
            eprintln!("carnine-backend: unknown argument: {argument}");
            eprint!("{USAGE}");
            std::process::exit(2);
        }
    }

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
        release_version = env!("CARNINE_VERSION"),
        build_id = env!("CARNINE_BUILD_ID"),
        "carnine backend bootstrap started; config={}",
        configuration_path.display()
    );
    // Listed again rather than returned by load(): the files are few, and a
    // drop-in that silently did not apply is exactly what this line is for.
    for drop_in in config::Config::drop_in_files(&configuration_path)? {
        info!("configuration drop-in applied: {}", drop_in.display());
    }

    if let Some(parent) = configuration.media.database_path.parent() {
        std::fs::create_dir_all(parent).with_context(|| {
            format!(
                "cannot create database directory {}; for development use a writable database path",
                parent.display()
            )
        })?;
    }
    std::fs::create_dir_all(&configuration.media.cover_cache_dir).with_context(|| {
        format!(
            "cannot create cover art cache directory {}; for development use a writable path",
            configuration.media.cover_cache_dir.display()
        )
    })?;
    let _database =
        database::Database::open(&configuration.media.database_path).with_context(|| {
            format!(
                "cannot open database {}; check its permissions or use a writable development path",
                configuration.media.database_path.display()
            )
        })?;
    let tcp_fallback = configuration
        .server
        .tcp_address
        .as_ref()
        .map(|address| address.parse())
        .transpose()?;
    let carnine_service = CarnineServiceImpl;
    let system_metrics = Arc::new(system_metrics::SystemMetricsHandle::new());
    system_metrics::spawn(
        Arc::clone(&system_metrics),
        system_metrics::SamplerSettings {
            cpu_interval: Duration::from_secs(configuration.system.metrics_interval_seconds),
            disk_interval: Duration::from_secs(configuration.system.disk_metrics_interval_seconds),
            disk_paths: configuration.disk_metric_paths(),
        },
    );
    let system_service = SystemServiceImpl::new(
        Arc::clone(&system_metrics),
        configuration.media.database_path.clone(),
    );
    let media_service = MediaServiceImpl::new_runtime(
        configuration.media.database_path.clone(),
        configuration.media.folders.clone(),
        configuration.media.supported_formats.clone(),
        configuration.media.resume_mode.clone(),
        configuration.media.cover_cache_dir.clone(),
    )?;
    let audio_volume = Arc::new(audio_volume::AudioVolume::new(PathBuf::from(
        "/var/lib/carnine/audio-volume",
    )));
    audio_volume.start();
    media_service.restore_resume_state()?;
    media_service.spawn_resume_saver();
    storage_events::spawn(Arc::new(media_service.clone()));
    let media_player = Arc::clone(&media_service.player);
    MediaPlayer::spawn_completion_watcher(Arc::clone(&media_player));
    let config_service = ConfigServiceImpl::new(configuration.clone(), configuration_path);
    let navigation_service = navigation::start(&configuration.navigation);

    let socket_mode = configuration.server.socket_permissions()?;
    if socket_mode != config::DEFAULT_SOCKET_MODE {
        // Loud on purpose: this is a deliberate weakening of the only thing
        // guarding the socket, and a reader of the log should see it.
        warn!(
            socket_mode = format!("{socket_mode:04o}"),
            "socket permissions widened beyond the production default 0600"
        );
    }
    info!(
        socket_path = %configuration.server.socket_path.display(),
        socket_mode = format!("{socket_mode:04o}"),
        tcp_fallback = ?tcp_fallback,
        "Starting gRPC server"
    );
    let incoming =
        server_transport::bind(&configuration.server.socket_path, tcp_fallback, socket_mode)
            .await?;
    let (shutdown_sender, shutdown_receiver) = oneshot::channel();
    let server = Server::builder()
        .add_service(CarnineServiceServer::new(carnine_service))
        .add_service(MediaServiceServer::new(media_service.clone()))
        .add_service(AudioServiceServer::new(AudioServiceImpl::with_events(
            media_service.player.audio_event_sender(),
            Arc::clone(&audio_volume),
        )))
        .add_service(ConfigServiceServer::new(config_service))
        .add_service(carnine::system_service_server::SystemServiceServer::new(
            system_service,
        ))
        .add_service(
            carnine::navigation_service_server::NavigationServiceServer::new(navigation_service),
        )
        .serve_with_incoming_shutdown(incoming, async move {
            let _ = shutdown_receiver.await;
        });
    tokio::pin!(server);
    tokio::select! {
        result = &mut server => result?,
        _ = shutdown_signal() => {
            if let Err(error) = media_service.save_resume_state() {
                warn!(%error, "failed to save resume state during shutdown");
            }
            if let Err(error) = media_player.shutdown() {
                warn!(%error, "failed to stop playback during shutdown");
            }
            if let Err(error) = media_player.shutdown_output() {
                warn!(%error, "failed to pause audio output during shutdown");
            }
            audio_volume.shutdown();
            let _ = shutdown_sender.send(());
            match tokio::time::timeout(Duration::from_secs(5), &mut server).await {
                Ok(result) => result?,
                Err(_) => warn!("gRPC shutdown grace period expired"),
            }
        }
    }

    let resume_result = media_service.save_resume_state();
    let player_result = media_player.shutdown();
    resume_result?;
    player_result?;
    warn!("gRPC server stopped");
    Ok(())
}

async fn shutdown_signal() {
    #[cfg(unix)]
    {
        use tokio::signal::unix::{signal, SignalKind};

        let mut terminate = signal(SignalKind::terminate()).expect("install SIGTERM handler");
        tokio::select! {
            _ = tokio::signal::ctrl_c() => warn!("shutdown requested by Ctrl+C"),
            _ = terminate.recv() => warn!("shutdown requested by SIGTERM"),
        }
    }

    #[cfg(not(unix))]
    {
        tokio::signal::ctrl_c()
            .await
            .expect("install Ctrl+C handler");
        warn!("shutdown requested by Ctrl+C");
    }
}

#[cfg(test)]
mod tests {
    use crate::audio_engine::{AudioEngine, Playback};
    use crate::carnine::{
        audio_service_server::AudioService, config_service_server::ConfigService,
        get_cover_art_request::Target as CoverArtTarget, media_service_server::MediaService,
        system_service_server::SystemService, AddPlaylistEntryRequest, AudioEventType,
        CreatePlaylistRequest, Empty, GetCoverArtRequest, GetPlaylistRequest, LibraryEventType,
        PlayerEventType, RepeatMode, RescanMediaRequest, SetRepeatModeRequest,
        SetShuffleModeRequest, SystemMetrics, UiState,
    };
    use crate::config;
    use crate::database;
    use crate::media_player::MediaPlayer;
    use crate::{parse_invocation, Invocation, USAGE};
    use anyhow::Result;
    use std::path::PathBuf;
    use std::sync::Arc;
    use std::time::Duration;
    use tokio_stream::StreamExt;
    use tonic::Request;

    #[test]
    fn no_arguments_run_the_service() {
        assert_eq!(parse_invocation(Vec::<String>::new()), Invocation::Run);
    }

    #[test]
    fn version_and_help_are_recognised_in_both_spellings() {
        for argument in ["--version", "-V"] {
            assert_eq!(
                parse_invocation([argument.to_owned()]),
                Invocation::ShowVersion
            );
        }
        for argument in ["--help", "-h"] {
            assert_eq!(
                parse_invocation([argument.to_owned()]),
                Invocation::ShowHelp
            );
        }
    }

    #[test]
    fn an_unrecognised_argument_is_reported_rather_than_ignored() {
        assert_eq!(
            parse_invocation(["--nonsense".to_owned()]),
            Invocation::Unknown("--nonsense".to_owned())
        );
    }

    #[test]
    fn the_usage_text_names_every_environment_override() {
        for variable in [
            "CARNINE_CONFIG",
            "CARNINE_LOG_DIRECTORY",
            "CARNINE_DATABASE_PATH",
            "CARNINE_SOCKET_PATH",
            "CARNINE_SOCKET_MODE",
            "CARNINE_TCP_ADDRESS",
        ] {
            assert!(USAGE.contains(variable), "usage text is missing {variable}");
        }
    }
    use super::{configuration_from_proto, configuration_to_proto, ConfigServiceImpl};
    use super::{system_metrics, AudioServiceImpl, MediaServiceImpl, SystemServiceImpl};

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
                socket_path: PathBuf::from("/tmp/carnine-test.sock"),
                tcp_address: Some("[::1]:50051".to_string()),
                socket_mode: None,
            },
            media: config::MediaConfig {
                database_path: PathBuf::from("/tmp/media.sqlite3"),
                folders: vec![PathBuf::from("/tmp/media")],
                supported_formats: vec!["mp3".to_string(), "flac".to_string()],
                rescan_on_start: true,
                resume_mode: "restore_paused".to_string(),
                cover_cache_dir: PathBuf::from("/tmp/carnine-covers"),
            },
            audio: config::AudioConfig {
                navigation_interrupt: "pause_music".to_string(),
            },
            logging: config::LoggingConfig {
                directory: PathBuf::from("/tmp/carnine-logs"),
                level: "info".to_string(),
            },
            system: config::SystemConfig::default(),
            navigation: config::NavigationConfig::default(),
        }
    }

    #[tokio::test]
    async fn system_service_acknowledges_ui_readiness() {
        let response =
            SystemService::report_ui_ready(&SystemServiceImpl::default(), Request::new(Empty {}))
                .await
                .expect("UI readiness should be acknowledged");

        assert!(response.into_inner().success);
    }

    #[tokio::test]
    async fn system_service_keeps_the_last_page_across_instances() {
        let database_path =
            std::env::temp_dir().join(format!("carnine-ui-state-{}.sqlite3", std::process::id()));
        let _ = std::fs::remove_file(&database_path);
        let metrics = Arc::new(system_metrics::SystemMetricsHandle::new());
        let service = SystemServiceImpl::new(Arc::clone(&metrics), database_path.clone());

        let initial = SystemService::get_ui_state(&service, Request::new(Empty {}))
            .await
            .expect("UI state should load before anything was saved")
            .into_inner();
        assert_eq!(initial.last_page, "");

        SystemService::save_ui_state(
            &service,
            Request::new(UiState {
                last_page: "maps".to_string(),
            }),
        )
        .await
        .expect("UI state should save");
        let too_long = SystemService::save_ui_state(
            &service,
            Request::new(UiState {
                last_page: "x".repeat(65),
            }),
        )
        .await
        .expect_err("an overlong page name is rejected");
        assert_eq!(too_long.code(), tonic::Code::InvalidArgument);

        // A new instance stands for the backend after a restart.
        let restarted = SystemServiceImpl::new(metrics, database_path.clone());
        let restored = SystemService::get_ui_state(&restarted, Request::new(Empty {}))
            .await
            .expect("UI state should load")
            .into_inner();
        assert_eq!(restored.last_page, "maps");
        let _ = std::fs::remove_file(database_path);
    }

    #[tokio::test]
    async fn system_service_serves_the_sampled_metrics() {
        let metrics = Arc::new(system_metrics::SystemMetricsHandle::new());
        let service = SystemServiceImpl::new(Arc::clone(&metrics), PathBuf::new());

        // Before the first sample the snapshot is empty but still answerable,
        // so a client that connects during startup does not get an error.
        let empty = SystemService::get_system_metrics(&service, Request::new(Empty {}))
            .await
            .expect("metrics should be answerable before the first sample")
            .into_inner();
        assert_eq!(empty.sampled_at_unix_ms, 0);

        let mut stream = SystemService::stream_system_metrics(&service, Request::new(Empty {}))
            .await
            .expect("metrics stream should open")
            .into_inner();
        let snapshot = stream
            .next()
            .await
            .expect("stream should open with a snapshot")
            .expect("snapshot should be valid");
        assert_eq!(snapshot.sampled_at_unix_ms, 0);

        metrics.publish_for_test(SystemMetrics {
            cpu_temperature_celsius: Some(41.5),
            load_average_1m: 0.75,
            sampled_at_unix_ms: 1_700_000_000_000,
            ..SystemMetrics::default()
        });

        let pushed = stream
            .next()
            .await
            .expect("stream should push the new sample")
            .expect("sample should be valid");
        assert_eq!(pushed.cpu_temperature_celsius, Some(41.5));
        assert_eq!(pushed.sampled_at_unix_ms, 1_700_000_000_000);

        let latest = SystemService::get_system_metrics(&service, Request::new(Empty {}))
            .await
            .expect("metrics should be answerable")
            .into_inner();
        assert_eq!(latest.load_average_1m, 0.75);
    }

    #[tokio::test]
    async fn media_and_audio_service_versions_match_central_version() {
        let configuration = test_configuration();
        let media = MediaServiceImpl::with_player(
            MediaPlayer::with_engine(Box::new(FakeAudioEngine)),
            configuration.media.database_path.clone(),
            configuration.media.folders.clone(),
            configuration.media.supported_formats.clone(),
            configuration.media.resume_mode.clone(),
            configuration.media.cover_cache_dir.clone(),
        );
        let audio = AudioServiceImpl::new();

        let media_version = MediaService::get_service_version(&media, Request::new(Empty {}))
            .await
            .expect("media version should be available")
            .into_inner();
        let audio_version = AudioService::get_service_version(&audio, Request::new(Empty {}))
            .await
            .expect("audio version should be available")
            .into_inner();

        assert_eq!(media_version, audio_version);
        assert_eq!(
            format!(
                "{}.{}.{}",
                media_version.major, media_version.minor, media_version.patch
            ),
            env!("CARNINE_VERSION")
        );
    }

    #[test]
    fn configuration_proto_roundtrip_preserves_values() {
        let original = test_configuration();
        let proto = configuration_to_proto(&original);
        let restored = configuration_from_proto(&proto).expect("configuration should be valid");

        assert_eq!(restored.server.socket_path, original.server.socket_path);
        assert_eq!(restored.server.tcp_address, original.server.tcp_address);
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
        assert_eq!(
            restored.media.cover_cache_dir,
            original.media.cover_cache_dir
        );
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
        configuration.database_path = String::new();

        assert!(configuration_from_proto(&configuration).is_err());
    }

    #[tokio::test]
    async fn update_configuration_keeps_the_navigation_section() {
        let path = std::env::temp_dir().join(format!(
            "carnine-config-navigation-test-{}.toml",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&path);
        let mut current = test_configuration();
        current.navigation.position_source = config::PositionSourceSetting::Replay;
        current.navigation.replay_file = Some(PathBuf::from("/var/lib/carnine/tour.nmea"));
        current.navigation.map_region = "hessen".to_string();
        let service = ConfigServiceImpl::new(current, path.clone());

        // The settings page sends the Configuration message, which has no
        // navigation fields at all.
        service
            .update_configuration(Request::new(super::UpdateConfigurationRequest {
                configuration: Some(configuration_to_proto(&test_configuration())),
            }))
            .await
            .expect("configuration update should succeed");

        let saved: config::Config =
            toml::from_str(&std::fs::read_to_string(&path).expect("configuration should be saved"))
                .expect("saved configuration should be valid TOML");
        assert_eq!(
            saved.navigation.position_source,
            config::PositionSourceSetting::Replay
        );
        assert_eq!(saved.navigation.map_region, "hessen");
        let _ = std::fs::remove_file(path);
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
        assert_eq!(
            saved_configuration.audio.navigation_interrupt,
            "pause_music"
        );
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
        let service = MediaServiceImpl::with_player(
            MediaPlayer::with_engine(Box::new(FakeAudioEngine)),
            database_path,
            vec![folder.clone()],
            vec!["mp3".to_string()],
            "restore_paused".to_string(),
            PathBuf::from("/tmp/carnine-covers"),
        );
        let response = service
            .rescan_media(Request::new(RescanMediaRequest {}))
            .await
            .expect("rescan should succeed");
        let events = response.into_inner().collect::<Vec<_>>().await;

        assert_eq!(events.len(), 3);
        assert_eq!(
            events[0].as_ref().expect("start event").event,
            LibraryEventType::LibraryScanStarted as i32
        );
        assert_eq!(
            events[1].as_ref().expect("progress event").event,
            LibraryEventType::LibraryProgress as i32
        );
        assert_eq!(events[1].as_ref().expect("progress event").imported, 1);
        assert_eq!(
            events[2].as_ref().expect("complete event").event,
            LibraryEventType::LibraryScanCompleted as i32
        );
        let _ = std::fs::remove_dir_all(folder);
    }

    #[tokio::test]
    async fn player_event_stream_starts_with_snapshot() {
        use tokio_stream::StreamExt;

        let service = MediaServiceImpl::with_player(
            MediaPlayer::with_engine(Box::new(FakeAudioEngine)),
            std::env::temp_dir().join(format!(
                "carnine-player-events-{}.sqlite3",
                std::process::id()
            )),
            Vec::new(),
            Vec::new(),
            "restore_paused".to_string(),
            PathBuf::from("/tmp/carnine-covers"),
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

        assert_eq!(event.event, PlayerEventType::PlayerSnapshot as i32);
        assert_eq!(event.state.expect("snapshot state").status, "stopped");

        let _ = service.player.execute("invalid", "");
        let event = events
            .next()
            .await
            .expect("error event should arrive")
            .expect("error event should be valid");

        assert_eq!(event.event, PlayerEventType::PlayerError as i32);
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
            PathBuf::from("/tmp/carnine-covers"),
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
        assert_eq!(snapshot.event, PlayerEventType::PlayerSnapshot as i32);

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
        assert_eq!(started.event, PlayerEventType::PlayerPlaybackStarted as i32);

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

        assert_eq!(first.event, PlayerEventType::PlayerPositionChanged as i32);
        assert_eq!(second.event, PlayerEventType::PlayerPositionChanged as i32);
        assert!(
            second.state.expect("second state should exist").position_ms
                >= first.state.expect("first state should exist").position_ms
        );
    }

    #[tokio::test]
    async fn player_event_stream_supports_multiple_subscribers() {
        let service = MediaServiceImpl::with_player(
            MediaPlayer::with_engine(Box::new(FakeAudioEngine)),
            std::env::temp_dir().join(format!(
                "carnine-multiple-player-events-{}.sqlite3",
                std::process::id()
            )),
            Vec::new(),
            Vec::new(),
            "restore_paused".to_string(),
            PathBuf::from("/tmp/carnine-covers"),
        );
        let mut first = service
            .stream_player_events(Request::new(Empty {}))
            .await
            .expect("first player stream should open")
            .into_inner();
        let mut second = service
            .stream_player_events(Request::new(Empty {}))
            .await
            .expect("second player stream should open")
            .into_inner();

        assert_eq!(
            first
                .next()
                .await
                .expect("first snapshot")
                .expect("valid event")
                .event,
            PlayerEventType::PlayerSnapshot as i32
        );
        assert_eq!(
            second
                .next()
                .await
                .expect("second snapshot")
                .expect("valid event")
                .event,
            PlayerEventType::PlayerSnapshot as i32
        );

        service
            .player
            .execute("invalid", "")
            .expect_err("invalid command should publish an error event");

        assert_eq!(
            first
                .next()
                .await
                .expect("first update")
                .expect("valid event")
                .event,
            PlayerEventType::PlayerError as i32
        );
        assert_eq!(
            second
                .next()
                .await
                .expect("second update")
                .expect("valid event")
                .event,
            PlayerEventType::PlayerError as i32
        );
    }

    #[tokio::test]
    async fn lagging_player_event_stream_reports_resource_exhausted() {
        let service = MediaServiceImpl::with_player(
            MediaPlayer::with_engine(Box::new(FakeAudioEngine)),
            std::env::temp_dir().join(format!(
                "carnine-lagging-player-events-{}.sqlite3",
                std::process::id()
            )),
            Vec::new(),
            Vec::new(),
            "restore_paused".to_string(),
            PathBuf::from("/tmp/carnine-covers"),
        );
        let mut events = service
            .stream_player_events(Request::new(Empty {}))
            .await
            .expect("player stream should open")
            .into_inner();
        let snapshot = events.next().await.expect("snapshot should exist");
        assert_eq!(
            snapshot.expect("snapshot should be valid").event,
            PlayerEventType::PlayerSnapshot as i32
        );

        for _ in 0..=32 {
            service
                .player
                .execute("invalid", "")
                .expect_err("invalid command should publish an error event");
        }

        let error = events
            .next()
            .await
            .expect("lagging stream should report an error")
            .expect_err("lagging stream should not silently drop events");
        assert_eq!(error.code(), tonic::Code::ResourceExhausted);
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

    #[test]
    fn queue_entry_rejects_index_outside_queue() {
        let player = MediaPlayer::with_engine(Box::new(FakeAudioEngine));
        player
            .play_playlist(1, vec![(10, "first.wav".to_string())], None, 0, "auto-play")
            .expect("fake playback should start");

        let error = player
            .execute("queue-entry", "1")
            .expect_err("out-of-range entry should fail");

        assert!(error.to_string().contains("queue index out of range"));
    }

    #[test]
    fn queue_entry_requires_active_playback() {
        let player = MediaPlayer::with_engine(Box::new(FakeAudioEngine));
        player
            .play_playlist(
                1,
                vec![(10, "first.wav".to_string())],
                None,
                0,
                "restore_paused",
            )
            .expect("playlist should load");

        let error = player
            .execute("queue-entry", "0")
            .expect_err("queue entry should require active playback");

        assert!(error.to_string().contains("no active playback"));
    }

    #[test]
    fn queue_entry_publishes_track_changed_event() {
        let player = MediaPlayer::with_engine(Box::new(FakeAudioEngine));
        let mut events = player.subscribe_events();
        player
            .play_playlist(
                1,
                vec![
                    (10, "first.wav".to_string()),
                    (11, "second.wav".to_string()),
                ],
                None,
                0,
                "auto-play",
            )
            .expect("fake playback should start");
        let _ = events.try_recv().expect("start event should be published");

        player
            .execute("queue-entry", "1")
            .expect("queue entry should start");
        let event = events.try_recv().expect("track event should be published");

        assert_eq!(event.event, PlayerEventType::PlayerTrackChanged as i32);
        assert_eq!(event.state.expect("event state").media_path, "second.wav");
    }

    #[tokio::test]
    async fn library_event_stream_receives_rescan_events() {
        let folder =
            std::env::temp_dir().join(format!("carnine-library-events-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&folder);
        std::fs::create_dir_all(&folder).expect("media folder should be created");
        let service = MediaServiceImpl::with_player(
            MediaPlayer::with_engine(Box::new(FakeAudioEngine)),
            folder.join("media.sqlite3"),
            vec![folder.clone()],
            vec!["mp3".to_string()],
            "restore_paused".to_string(),
            PathBuf::from("/tmp/carnine-covers"),
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
        assert_eq!(event.event, LibraryEventType::LibraryScanStarted as i32);
        let _ = std::fs::remove_dir_all(folder);
    }

    #[tokio::test]
    async fn audio_event_stream_starts_with_status_and_receives_updates() {
        let service = AudioServiceImpl::new();
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
        assert_eq!(snapshot.event, AudioEventType::AudioReady as i32);
        assert_eq!(snapshot.message, "audio ready");

        service.publish(AudioEventType::AudioDeviceChanged, "audio device changed");
        let event = events
            .next()
            .await
            .expect("audio update should arrive")
            .expect("audio update should be valid");
        assert_eq!(event.event, AudioEventType::AudioDeviceChanged as i32);
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
                cover_path: None,
            })
            .expect("media should save");
        let playlist_id = database
            .create_playlist("Resume")
            .expect("playlist should save");
        let playlist_entry_id = database
            .add_playlist_entry(playlist_id, media_id)
            .expect("playlist entry should save");
        drop(database);
        let service = MediaServiceImpl::with_player(
            MediaPlayer::with_engine(Box::new(FakeAudioEngine)),
            database_path.clone(),
            Vec::new(),
            Vec::new(),
            "restore_paused".to_string(),
            PathBuf::from("/tmp/carnine-covers"),
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
        service.player.set_repeat_mode(RepeatMode::RepeatQueue);
        service.player.set_shuffle_mode(true);
        service
            .save_resume_state()
            .expect("resume context should save");

        let restored_service = MediaServiceImpl::with_player(
            MediaPlayer::with_engine(Box::new(FakeAudioEngine)),
            database_path.clone(),
            Vec::new(),
            Vec::new(),
            "restore_paused".to_string(),
            PathBuf::from("/tmp/carnine-covers"),
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
        assert_eq!(
            restored_service.player.repeat_mode(),
            RepeatMode::RepeatQueue
        );
        assert!(restored_service.player.shuffle_enabled());
        let _ = std::fs::remove_file(database_path);
    }

    #[tokio::test]
    async fn a_track_change_saves_the_resume_state() {
        let database_path = std::env::temp_dir().join(format!(
            "carnine-resume-saver-{}.sqlite3",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&database_path);
        let database = database::Database::open(&database_path).expect("database should open");
        let source_id = database
            .upsert_source("/music", "AVAILABLE")
            .expect("source should save");
        let playlist_id = database
            .create_playlist("Saver")
            .expect("playlist should be created");
        let mut entries = Vec::new();
        for name in ["first", "second"] {
            let path = format!("/music/{name}.mp3");
            let media_id = database
                .upsert_media(&database::MediaRecord {
                    id: 0,
                    source_id,
                    path: path.clone(),
                    title: name.to_string(),
                    artist: "Artist".to_string(),
                    duration_ms: 100_000,
                    status: "AVAILABLE".to_string(),
                    cover_path: None,
                })
                .expect("media should save");
            let entry_id = database
                .add_playlist_entry(playlist_id, media_id)
                .expect("entry should save");
            entries.push((entry_id, path));
        }
        drop(database);
        let service = MediaServiceImpl::with_player(
            MediaPlayer::with_engine(Box::new(FakeAudioEngine)),
            database_path.clone(),
            Vec::new(),
            Vec::new(),
            "restore_paused".to_string(),
            PathBuf::from("/tmp/carnine-covers"),
        );
        service
            .player
            .play_playlist(
                playlist_id as i64,
                entries.clone(),
                Some(entries[0].0),
                90_000,
                "auto-play",
            )
            .expect("playlist should start");
        service.spawn_resume_saver();

        service
            .player
            .execute("queue-entry", "1")
            .expect("second track should start");

        let deadline = std::time::Instant::now() + Duration::from_secs(5);
        let saved = loop {
            let state = database::Database::open(&database_path)
                .expect("database should open")
                .load_resume_state()
                .expect("resume state should load");
            if let Some(state) = state.filter(|state| state.playlist_entry_id == Some(entries[1].0))
            {
                break state;
            }
            assert!(
                std::time::Instant::now() < deadline,
                "the track change was never saved"
            );
            tokio::time::sleep(Duration::from_millis(20)).await;
        };
        assert!(saved.position_ms < 1_000, "{} ms", saved.position_ms);
        let _ = std::fs::remove_file(database_path);
    }

    #[tokio::test]
    async fn changing_repeat_or_shuffle_is_saved_without_a_stop() {
        let database_path = std::env::temp_dir().join(format!(
            "carnine-repeat-saved-{}.sqlite3",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&database_path);
        let service_at = |path: &PathBuf| {
            MediaServiceImpl::with_player(
                MediaPlayer::with_engine(Box::new(FakeAudioEngine)),
                path.clone(),
                Vec::new(),
                Vec::new(),
                "restore_paused".to_string(),
                PathBuf::from("/tmp/carnine-covers"),
            )
        };
        let service = service_at(&database_path);
        service
            .set_repeat_mode(Request::new(SetRepeatModeRequest {
                mode: RepeatMode::RepeatQueue as i32,
            }))
            .await
            .expect("repeat mode should be set");
        service
            .set_shuffle_mode(Request::new(SetShuffleModeRequest { enabled: true }))
            .await
            .expect("shuffle mode should be set");

        // No stop and no SIGTERM, as when the car's power goes.
        let restored = service_at(&database_path);
        restored
            .restore_resume_state()
            .expect("resume state should restore");
        assert_eq!(restored.player.repeat_mode(), RepeatMode::RepeatQueue);
        assert!(restored.player.shuffle_enabled());
        let _ = std::fs::remove_file(database_path);
    }

    fn playlist_test_service(database_path: PathBuf, cover_cache_dir: PathBuf) -> MediaServiceImpl {
        MediaServiceImpl::with_player(
            MediaPlayer::with_engine(Box::new(FakeAudioEngine)),
            database_path,
            Vec::new(),
            Vec::new(),
            "restore_paused".to_string(),
            cover_cache_dir,
        )
    }

    /// The event that offers a USB volume is broadcast once, while the service
    /// starts. On the Pi the UI comes up seconds later - it must still be
    /// offered the import, or the banner never appears.
    #[tokio::test]
    async fn a_volume_found_before_a_client_connects_is_still_offered() {
        let directory =
            std::env::temp_dir().join(format!("carnine-pending-volume-{}", std::process::id()));
        std::fs::create_dir_all(&directory).expect("source directory should be creatable");
        std::fs::write(directory.join("track.mp3"), b"not really audio")
            .expect("source file should be writable");
        let service = playlist_test_service(
            directory.join("library.sqlite3"),
            PathBuf::from("/tmp/carnine-covers"),
        );

        service
            .discover_music_volume("MUSIK".to_string(), directory.clone())
            .expect("discovery should succeed");

        // Only now does the client turn up.
        let mut events = service
            .stream_library_events(Request::new(Empty {}))
            .await
            .expect("library events should open")
            .into_inner();
        // Bounded on purpose: without the replay this stream simply stays
        // silent, and an unbounded await would hang the whole suite instead
        // of reporting the regression.
        let event = tokio::time::timeout(Duration::from_secs(5), events.next())
            .await
            .expect("a client connecting after the volume was found got nothing at all")
            .expect("the pending volume should be replayed")
            .expect("the replayed event should not be an error");

        assert_eq!(event.event, LibraryEventType::LibraryMusicFound as i32);
        assert_eq!(event.source_path, directory.display().to_string());
        assert_eq!(event.matching_files, 1);

        let _ = std::fs::remove_dir_all(&directory);
    }

    #[tokio::test]
    async fn a_volume_that_disappeared_is_no_longer_offered() {
        let directory =
            std::env::temp_dir().join(format!("carnine-vanished-volume-{}", std::process::id()));
        std::fs::create_dir_all(&directory).expect("source directory should be creatable");
        std::fs::write(directory.join("track.mp3"), b"not really audio")
            .expect("source file should be writable");
        let service = playlist_test_service(
            directory.join("library.sqlite3"),
            PathBuf::from("/tmp/carnine-covers"),
        );
        service
            .discover_music_volume("MUSIK".to_string(), directory.clone())
            .expect("discovery should succeed");

        // The next inspection sees no MUSIK volume at all - the stick is out.
        service.forget_absent_music_volumes(&[]);

        assert!(
            service.take_pending_music_volume().is_none(),
            "an offer for a volume that is gone must not survive"
        );

        let _ = std::fs::remove_dir_all(&directory);
    }

    #[tokio::test]
    async fn a_volume_that_is_still_there_stays_on_offer() {
        let directory =
            std::env::temp_dir().join(format!("carnine-kept-volume-{}", std::process::id()));
        std::fs::create_dir_all(&directory).expect("source directory should be creatable");
        std::fs::write(directory.join("track.mp3"), b"not really audio")
            .expect("source file should be writable");
        let service = playlist_test_service(
            directory.join("library.sqlite3"),
            PathBuf::from("/tmp/carnine-covers"),
        );
        service
            .discover_music_volume("MUSIK".to_string(), directory.clone())
            .expect("discovery should succeed");

        service.forget_absent_music_volumes(std::slice::from_ref(&directory));

        assert!(
            service.take_pending_music_volume().is_some(),
            "the volume is still mounted, so the offer has to stand"
        );

        let _ = std::fs::remove_dir_all(&directory);
    }

    #[tokio::test]
    async fn set_repeat_mode_updates_player_state() {
        let database_path = std::env::temp_dir().join(format!(
            "carnine-repeat-mode-{}.sqlite3",
            std::process::id()
        ));
        let service =
            playlist_test_service(database_path.clone(), PathBuf::from("/tmp/carnine-covers"));

        let response = service
            .set_repeat_mode(Request::new(SetRepeatModeRequest {
                mode: RepeatMode::RepeatQueue as i32,
            }))
            .await
            .expect("repeat mode should be accepted")
            .into_inner();
        assert!(response.success);

        let state = service
            .get_player_state(Request::new(Empty {}))
            .await
            .expect("player state should load")
            .into_inner();
        assert_eq!(state.repeat_mode(), RepeatMode::RepeatQueue);
    }

    #[tokio::test]
    async fn set_shuffle_mode_updates_player_state() {
        let database_path = std::env::temp_dir().join(format!(
            "carnine-shuffle-mode-{}.sqlite3",
            std::process::id()
        ));
        let service =
            playlist_test_service(database_path.clone(), PathBuf::from("/tmp/carnine-covers"));

        let response = service
            .set_shuffle_mode(Request::new(SetShuffleModeRequest { enabled: true }))
            .await
            .expect("shuffle mode should be accepted")
            .into_inner();
        assert!(response.success);

        let state = service
            .get_player_state(Request::new(Empty {}))
            .await
            .expect("player state should load")
            .into_inner();
        assert!(state.shuffle_enabled);
    }

    #[tokio::test]
    async fn create_playlist_returns_new_playlist_without_entries_or_cover() {
        let database_path = std::env::temp_dir().join(format!(
            "carnine-playlist-create-{}.sqlite3",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&database_path);
        let service =
            playlist_test_service(database_path.clone(), PathBuf::from("/tmp/carnine-covers"));

        let playlist = service
            .create_playlist(Request::new(CreatePlaylistRequest {
                name: "Favorites".to_string(),
            }))
            .await
            .expect("playlist should be created")
            .into_inner();

        assert_eq!(playlist.name, "Favorites");
        assert!(playlist.entries.is_empty());
        assert!(!playlist.has_cover_art);
        let _ = std::fs::remove_file(database_path);
    }

    #[tokio::test]
    async fn create_playlist_emits_playlist_created_event() {
        let database_path = std::env::temp_dir().join(format!(
            "carnine-playlist-create-event-{}.sqlite3",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&database_path);
        let service =
            playlist_test_service(database_path.clone(), PathBuf::from("/tmp/carnine-covers"));
        let mut events = service.library_events.subscribe();

        let playlist = service
            .create_playlist(Request::new(CreatePlaylistRequest {
                name: "Favorites".to_string(),
            }))
            .await
            .expect("playlist should be created")
            .into_inner();

        let event = events
            .try_recv()
            .expect("a playlist_created event should have been broadcast");
        assert_eq!(event.event, LibraryEventType::PlaylistCreated as i32);
        assert_eq!(event.playlist_id, playlist.id);
        assert_eq!(event.playlist_name, "Favorites");
        let _ = std::fs::remove_file(database_path);
    }

    #[tokio::test]
    async fn create_playlist_rejects_empty_name() {
        let database_path = std::env::temp_dir().join(format!(
            "carnine-playlist-empty-name-{}.sqlite3",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&database_path);
        let service =
            playlist_test_service(database_path.clone(), PathBuf::from("/tmp/carnine-covers"));

        let status = service
            .create_playlist(Request::new(CreatePlaylistRequest {
                name: "  ".to_string(),
            }))
            .await
            .expect_err("empty playlist name should be rejected");

        assert_eq!(status.code(), tonic::Code::InvalidArgument);
        let _ = std::fs::remove_file(database_path);
    }

    #[tokio::test]
    async fn create_playlist_rejects_duplicate_name() {
        let database_path = std::env::temp_dir().join(format!(
            "carnine-playlist-duplicate-{}.sqlite3",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&database_path);
        let service =
            playlist_test_service(database_path.clone(), PathBuf::from("/tmp/carnine-covers"));
        service
            .create_playlist(Request::new(CreatePlaylistRequest {
                name: "Favorites".to_string(),
            }))
            .await
            .expect("first playlist should be created");

        let status = service
            .create_playlist(Request::new(CreatePlaylistRequest {
                name: "Favorites".to_string(),
            }))
            .await
            .expect_err("duplicate playlist name should be rejected");

        assert_eq!(status.code(), tonic::Code::AlreadyExists);
        let _ = std::fs::remove_file(database_path);
    }

    #[tokio::test]
    async fn list_playlists_returns_created_playlists_in_stable_order() {
        let database_path = std::env::temp_dir().join(format!(
            "carnine-playlist-list-{}.sqlite3",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&database_path);
        let service =
            playlist_test_service(database_path.clone(), PathBuf::from("/tmp/carnine-covers"));
        service
            .create_playlist(Request::new(CreatePlaylistRequest {
                name: "zeta".to_string(),
            }))
            .await
            .expect("first playlist should be created");
        service
            .create_playlist(Request::new(CreatePlaylistRequest {
                name: "Alpha".to_string(),
            }))
            .await
            .expect("second playlist should be created");

        let response = service
            .list_playlists(Request::new(Empty {}))
            .await
            .expect("playlists should be listed")
            .into_inner();

        assert_eq!(
            response
                .playlists
                .iter()
                .map(|playlist| playlist.name.as_str())
                .collect::<Vec<_>>(),
            ["Alpha", "zeta"]
        );
        let _ = std::fs::remove_file(database_path);
    }

    #[tokio::test]
    async fn add_playlist_entry_returns_created_entry() {
        let database_path = std::env::temp_dir().join(format!(
            "carnine-playlist-add-entry-{}.sqlite3",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&database_path);
        let database = database::Database::open(&database_path).expect("database should open");
        let source_id = database
            .upsert_source("/music", "AVAILABLE")
            .expect("source should be stored");
        let media_id = database
            .upsert_media(&database::MediaRecord {
                id: 0,
                source_id,
                path: "/music/song.mp3".to_string(),
                title: "Song".to_string(),
                artist: "Artist".to_string(),
                duration_ms: 1000,
                status: "AVAILABLE".to_string(),
                cover_path: None,
            })
            .expect("media should be stored");
        drop(database);
        let service =
            playlist_test_service(database_path.clone(), PathBuf::from("/tmp/carnine-covers"));
        let playlist = service
            .create_playlist(Request::new(CreatePlaylistRequest {
                name: "Favorites".to_string(),
            }))
            .await
            .expect("playlist should be created")
            .into_inner();

        let entry = service
            .add_playlist_entry(Request::new(AddPlaylistEntryRequest {
                playlist_id: playlist.id,
                media_id: media_id as u64,
            }))
            .await
            .expect("playlist entry should be added")
            .into_inner();

        assert_eq!(entry.playlist_id, playlist.id);
        assert_eq!(entry.media_id, media_id as u64);
        assert_eq!(entry.position, 0);
        let _ = std::fs::remove_file(database_path);
    }

    #[tokio::test]
    async fn add_playlist_entry_emits_playlist_entry_added_event() {
        let database_path = std::env::temp_dir().join(format!(
            "carnine-playlist-add-entry-event-{}.sqlite3",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&database_path);
        let database = database::Database::open(&database_path).expect("database should open");
        let source_id = database
            .upsert_source("/music", "AVAILABLE")
            .expect("source should be stored");
        let media_id = database
            .upsert_media(&database::MediaRecord {
                id: 0,
                source_id,
                path: "/music/song.mp3".to_string(),
                title: "Song".to_string(),
                artist: "Artist".to_string(),
                duration_ms: 1000,
                status: "AVAILABLE".to_string(),
                cover_path: None,
            })
            .expect("media should be stored");
        drop(database);
        let service =
            playlist_test_service(database_path.clone(), PathBuf::from("/tmp/carnine-covers"));
        let playlist = service
            .create_playlist(Request::new(CreatePlaylistRequest {
                name: "Favorites".to_string(),
            }))
            .await
            .expect("playlist should be created")
            .into_inner();
        let mut events = service.library_events.subscribe();

        service
            .add_playlist_entry(Request::new(AddPlaylistEntryRequest {
                playlist_id: playlist.id,
                media_id: media_id as u64,
            }))
            .await
            .expect("playlist entry should be added");

        let event = events
            .try_recv()
            .expect("a playlist_entry_added event should have been broadcast");
        assert_eq!(event.event, LibraryEventType::PlaylistEntryAdded as i32);
        assert_eq!(event.playlist_id, playlist.id);
        let _ = std::fs::remove_file(database_path);
    }

    #[tokio::test]
    async fn add_playlist_entry_rejects_unknown_playlist() {
        let database_path = std::env::temp_dir().join(format!(
            "carnine-playlist-add-entry-unknown-{}.sqlite3",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&database_path);
        let service =
            playlist_test_service(database_path.clone(), PathBuf::from("/tmp/carnine-covers"));

        let status = service
            .add_playlist_entry(Request::new(AddPlaylistEntryRequest {
                playlist_id: 999,
                media_id: 1,
            }))
            .await
            .expect_err("unknown playlist should be rejected");

        assert_eq!(status.code(), tonic::Code::InvalidArgument);
        let _ = std::fs::remove_file(database_path);
    }

    #[tokio::test]
    async fn get_playlist_rejects_unknown_id() {
        let database_path = std::env::temp_dir().join(format!(
            "carnine-playlist-get-unknown-{}.sqlite3",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&database_path);
        let service =
            playlist_test_service(database_path.clone(), PathBuf::from("/tmp/carnine-covers"));

        let status = service
            .get_playlist(Request::new(GetPlaylistRequest { playlist_id: 999 }))
            .await
            .expect_err("unknown playlist id should be rejected");

        assert_eq!(status.code(), tonic::Code::NotFound);
        let _ = std::fs::remove_file(database_path);
    }

    #[tokio::test]
    async fn get_playlist_reports_has_cover_art_true_when_a_track_has_cover() {
        let database_path = std::env::temp_dir().join(format!(
            "carnine-playlist-cover-true-{}.sqlite3",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&database_path);
        let database = database::Database::open(&database_path).expect("database should open");
        let source_id = database
            .upsert_source("/music", "AVAILABLE")
            .expect("source should be stored");
        let media_id = database
            .upsert_media(&database::MediaRecord {
                id: 0,
                source_id,
                path: "/music/song.mp3".to_string(),
                title: "Song".to_string(),
                artist: "Artist".to_string(),
                duration_ms: 1000,
                status: "AVAILABLE".to_string(),
                cover_path: Some("abc123.jpg".to_string()),
            })
            .expect("media should be stored");
        let playlist_id = database
            .create_playlist("Favorites")
            .expect("playlist should be created");
        database
            .add_playlist_entry(playlist_id, media_id)
            .expect("entry should be added");
        drop(database);
        let service =
            playlist_test_service(database_path.clone(), PathBuf::from("/tmp/carnine-covers"));

        let playlist = service
            .get_playlist(Request::new(GetPlaylistRequest {
                playlist_id: playlist_id as u64,
            }))
            .await
            .expect("playlist should be found")
            .into_inner();

        assert_eq!(playlist.entries.len(), 1);
        assert!(playlist.has_cover_art);
        let _ = std::fs::remove_file(database_path);
    }

    #[tokio::test]
    async fn get_playlist_reports_has_cover_art_false_when_no_track_has_cover() {
        let database_path = std::env::temp_dir().join(format!(
            "carnine-playlist-cover-false-{}.sqlite3",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&database_path);
        let database = database::Database::open(&database_path).expect("database should open");
        let source_id = database
            .upsert_source("/music", "AVAILABLE")
            .expect("source should be stored");
        let media_id = database
            .upsert_media(&database::MediaRecord {
                id: 0,
                source_id,
                path: "/music/song.mp3".to_string(),
                title: "Song".to_string(),
                artist: "Artist".to_string(),
                duration_ms: 1000,
                status: "AVAILABLE".to_string(),
                cover_path: None,
            })
            .expect("media should be stored");
        let playlist_id = database
            .create_playlist("Favorites")
            .expect("playlist should be created");
        database
            .add_playlist_entry(playlist_id, media_id)
            .expect("entry should be added");
        drop(database);
        let service =
            playlist_test_service(database_path.clone(), PathBuf::from("/tmp/carnine-covers"));

        let playlist = service
            .get_playlist(Request::new(GetPlaylistRequest {
                playlist_id: playlist_id as u64,
            }))
            .await
            .expect("playlist should be found")
            .into_inner();

        assert!(!playlist.has_cover_art);
        let _ = std::fs::remove_file(database_path);
    }

    #[tokio::test]
    async fn get_cover_art_returns_bytes_and_mime_type_for_media_with_cover() {
        let database_path = std::env::temp_dir().join(format!(
            "carnine-cover-art-media-{}.sqlite3",
            std::process::id()
        ));
        let cover_cache_dir = std::env::temp_dir().join(format!(
            "carnine-cover-art-media-cache-{}",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&database_path);
        std::fs::create_dir_all(&cover_cache_dir).expect("cover cache dir should be created");
        std::fs::write(cover_cache_dir.join("abc123.jpg"), b"fake-jpeg-bytes")
            .expect("fixture cover file should be written");
        let database = database::Database::open(&database_path).expect("database should open");
        let source_id = database
            .upsert_source("/music", "AVAILABLE")
            .expect("source should be stored");
        let media_id = database
            .upsert_media(&database::MediaRecord {
                id: 0,
                source_id,
                path: "/music/song.mp3".to_string(),
                title: "Song".to_string(),
                artist: "Artist".to_string(),
                duration_ms: 1000,
                status: "AVAILABLE".to_string(),
                cover_path: Some("abc123.jpg".to_string()),
            })
            .expect("media should be stored");
        drop(database);
        let service = playlist_test_service(database_path.clone(), cover_cache_dir.clone());

        let response = service
            .get_cover_art(Request::new(GetCoverArtRequest {
                target: Some(CoverArtTarget::MediaId(media_id as u64)),
            }))
            .await
            .expect("cover art should be returned")
            .into_inner();

        assert_eq!(response.data, b"fake-jpeg-bytes");
        assert_eq!(response.mime_type, "image/jpeg");
        let _ = std::fs::remove_file(database_path);
        let _ = std::fs::remove_dir_all(cover_cache_dir);
    }

    #[tokio::test]
    async fn get_cover_art_infers_png_mime_type_from_extension() {
        let database_path = std::env::temp_dir().join(format!(
            "carnine-cover-art-png-{}.sqlite3",
            std::process::id()
        ));
        let cover_cache_dir = std::env::temp_dir().join(format!(
            "carnine-cover-art-png-cache-{}",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&database_path);
        std::fs::create_dir_all(&cover_cache_dir).expect("cover cache dir should be created");
        std::fs::write(cover_cache_dir.join("abc123.png"), b"fake-png-bytes")
            .expect("fixture cover file should be written");
        let database = database::Database::open(&database_path).expect("database should open");
        let source_id = database
            .upsert_source("/music", "AVAILABLE")
            .expect("source should be stored");
        let media_id = database
            .upsert_media(&database::MediaRecord {
                id: 0,
                source_id,
                path: "/music/song.mp3".to_string(),
                title: "Song".to_string(),
                artist: "Artist".to_string(),
                duration_ms: 1000,
                status: "AVAILABLE".to_string(),
                cover_path: Some("abc123.png".to_string()),
            })
            .expect("media should be stored");
        drop(database);
        let service = playlist_test_service(database_path.clone(), cover_cache_dir.clone());

        let response = service
            .get_cover_art(Request::new(GetCoverArtRequest {
                target: Some(CoverArtTarget::MediaId(media_id as u64)),
            }))
            .await
            .expect("cover art should be returned")
            .into_inner();

        assert_eq!(response.mime_type, "image/png");
        let _ = std::fs::remove_file(database_path);
        let _ = std::fs::remove_dir_all(cover_cache_dir);
    }

    #[tokio::test]
    async fn get_cover_art_returns_not_found_for_media_without_cover() {
        let database_path = std::env::temp_dir().join(format!(
            "carnine-cover-art-missing-{}.sqlite3",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&database_path);
        let database = database::Database::open(&database_path).expect("database should open");
        let source_id = database
            .upsert_source("/music", "AVAILABLE")
            .expect("source should be stored");
        let media_id = database
            .upsert_media(&database::MediaRecord {
                id: 0,
                source_id,
                path: "/music/song.mp3".to_string(),
                title: "Song".to_string(),
                artist: "Artist".to_string(),
                duration_ms: 1000,
                status: "AVAILABLE".to_string(),
                cover_path: None,
            })
            .expect("media should be stored");
        drop(database);
        let service =
            playlist_test_service(database_path.clone(), PathBuf::from("/tmp/carnine-covers"));

        let status = service
            .get_cover_art(Request::new(GetCoverArtRequest {
                target: Some(CoverArtTarget::MediaId(media_id as u64)),
            }))
            .await
            .expect_err("missing cover art should be reported as not found");

        assert_eq!(status.code(), tonic::Code::NotFound);
        let _ = std::fs::remove_file(database_path);
    }

    #[tokio::test]
    async fn get_cover_art_returns_bytes_for_playlist_via_first_covered_track() {
        let database_path = std::env::temp_dir().join(format!(
            "carnine-cover-art-playlist-{}.sqlite3",
            std::process::id()
        ));
        let cover_cache_dir = std::env::temp_dir().join(format!(
            "carnine-cover-art-playlist-cache-{}",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&database_path);
        std::fs::create_dir_all(&cover_cache_dir).expect("cover cache dir should be created");
        std::fs::write(cover_cache_dir.join("cover.jpg"), b"fake-jpeg-bytes")
            .expect("fixture cover file should be written");
        let database = database::Database::open(&database_path).expect("database should open");
        let source_id = database
            .upsert_source("/music", "AVAILABLE")
            .expect("source should be stored");
        let uncovered_media_id = database
            .upsert_media(&database::MediaRecord {
                id: 0,
                source_id,
                path: "/music/uncovered.mp3".to_string(),
                title: "Uncovered".to_string(),
                artist: "Artist".to_string(),
                duration_ms: 1000,
                status: "AVAILABLE".to_string(),
                cover_path: None,
            })
            .expect("uncovered media should be stored");
        let covered_media_id = database
            .upsert_media(&database::MediaRecord {
                id: 0,
                source_id,
                path: "/music/covered.mp3".to_string(),
                title: "Covered".to_string(),
                artist: "Artist".to_string(),
                duration_ms: 1000,
                status: "AVAILABLE".to_string(),
                cover_path: Some("cover.jpg".to_string()),
            })
            .expect("covered media should be stored");
        let playlist_id = database
            .create_playlist("Favorites")
            .expect("playlist should be created");
        database
            .add_playlist_entry(playlist_id, uncovered_media_id)
            .expect("first entry should be added");
        database
            .add_playlist_entry(playlist_id, covered_media_id)
            .expect("second entry should be added");
        drop(database);
        let service = playlist_test_service(database_path.clone(), cover_cache_dir.clone());

        let response = service
            .get_cover_art(Request::new(GetCoverArtRequest {
                target: Some(CoverArtTarget::PlaylistId(playlist_id as u64)),
            }))
            .await
            .expect("playlist cover art should be returned")
            .into_inner();

        assert_eq!(response.data, b"fake-jpeg-bytes");
        assert_eq!(response.mime_type, "image/jpeg");
        let _ = std::fs::remove_file(database_path);
        let _ = std::fs::remove_dir_all(cover_cache_dir);
    }

    #[tokio::test]
    async fn get_cover_art_rejects_missing_target() {
        let database_path = std::env::temp_dir().join(format!(
            "carnine-cover-art-no-target-{}.sqlite3",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&database_path);
        let service =
            playlist_test_service(database_path.clone(), PathBuf::from("/tmp/carnine-covers"));

        let status = service
            .get_cover_art(Request::new(GetCoverArtRequest { target: None }))
            .await
            .expect_err("missing target should be rejected");

        assert_eq!(status.code(), tonic::Code::InvalidArgument);
        let _ = std::fs::remove_file(database_path);
    }
}

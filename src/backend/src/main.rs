use std::sync::Arc;
use std::{fs, path::PathBuf, sync::Mutex};

use anyhow::{bail, Context, Result};
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

use carnine::{
    audio_service_server::{AudioService, AudioServiceServer},
    carnine_service_server::{CarnineService, CarnineServiceServer},
    config_service_server::{ConfigService, ConfigServiceServer},
    media_service_server::{MediaService, MediaServiceServer},
    AudioEvent, CanData, CanDataRequest, CanDataResponse, CommandResponse, Configuration,
    ConfigurationResponse, Empty, PlayRequest, PlayerEvent, PlayerState, ServiceVersion,
    UpdateConfigurationRequest,
};

use media_player::MediaPlayer;

#[derive(Debug, Default)]
pub struct CarnineServiceImpl;

pub struct MediaServiceImpl {
    player: Arc<MediaPlayer>,
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
    fn new(audio_config: &config::AudioConfig) -> Self {
        Self {
            player: Arc::new(MediaPlayer::from_audio_config(audio_config)),
        }
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
        let yaml =
            serde_yaml::to_string(&updated).map_err(|error| Status::internal(error.to_string()))?;
        let temporary_path = self.path.with_extension("yaml.tmp");
        fs::write(&temporary_path, yaml).map_err(|error| Status::internal(error.to_string()))?;
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

#[derive(Debug, Default)]
pub struct AudioServiceImpl;

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
        tokio_stream::Iter<std::vec::IntoIter<Result<PlayerEvent, Status>>>;

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

    async fn get_player_state(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<PlayerState>, Status> {
        Ok(Response::new(PlayerState {
            status: self.player.state().to_string(),
            media_path: self.player.media_path(),
            position_ms: 0,
            duration_ms: 0,
        }))
    }

    async fn stream_player_events(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<Self::StreamPlayerEventsStream>, Status> {
        Ok(Response::new(tokio_stream::iter(Vec::new())))
    }
}

impl MediaServiceImpl {
    fn command(
        &self,
        command: &str,
        parameters: String,
    ) -> Result<Response<CommandResponse>, Status> {
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
        tokio_stream::Iter<std::vec::IntoIter<Result<AudioEvent, Status>>>;

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
        Ok(Response::new(tokio_stream::iter(Vec::new())))
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
    std::fs::create_dir_all(&configuration.logging.directory)?;
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
        std::fs::create_dir_all(parent)?;
    }
    let _database = database::Database::open(&configuration.media.database_path)?;
    let addr = configuration.server.address.parse()?;
    let carnine_service = CarnineServiceImpl::default();
    let media_service = MediaServiceImpl::new(&configuration.audio);
    let media_player = Arc::clone(&media_service.player);
    let config_service = ConfigServiceImpl::new(configuration.clone(), configuration_path);

    info!("Starting gRPC server on {}", addr);
    Server::builder()
        .add_service(CarnineServiceServer::new(carnine_service))
        .add_service(MediaServiceServer::new(media_service))
        .add_service(AudioServiceServer::new(AudioServiceImpl::default()))
        .add_service(ConfigServiceServer::new(config_service))
        .serve_with_shutdown(addr, shutdown_signal())
        .await?;

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
    use crate::carnine::config_service_server::ConfigService;
    use crate::config;
    use std::path::PathBuf;
    use tonic::Request;

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
            std::env::temp_dir().join(format!("carnine-config-test-{}.yaml", std::process::id()));
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
            serde_yaml::from_str(&saved).expect("saved configuration should be valid YAML");
        assert_eq!(saved_configuration.audio.device, "plughw:1,0");
        let _ = std::fs::remove_file(path);
    }
}

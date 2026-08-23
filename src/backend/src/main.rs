use anyhow::Result;
use tonic::{transport::Server, Request, Response, Status};
use tracing::{info, warn};
use tracing_appender::rolling;
use tracing_subscriber::prelude::*;

pub mod carnine {
    tonic::include_proto!("carnine");
}

mod audio_engine;
mod config;
mod media_player;

use carnine::{
    audio_service_server::{AudioService, AudioServiceServer},
    carnine_service_server::{CarnineService, CarnineServiceServer},
    media_service_server::{MediaService, MediaServiceServer},
    AudioEvent, CanData, CanDataRequest, CanDataResponse, CommandResponse, Empty, PlayRequest,
    PlayerEvent, PlayerState, ServiceVersion,
};

use media_player::MediaPlayer;

#[derive(Debug, Default)]
pub struct CarnineServiceImpl;

pub struct MediaServiceImpl {
    player: MediaPlayer,
}

impl MediaServiceImpl {
    fn new(audio_config: &config::AudioConfig) -> Self {
        Self {
            player: MediaPlayer::from_audio_config(audio_config),
        }
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
            media_path: String::new(),
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

    let addr = configuration.server.address.parse()?;
    let carnine_service = CarnineServiceImpl::default();

    info!("Starting gRPC server on {}", addr);
    Server::builder()
        .add_service(CarnineServiceServer::new(carnine_service))
        .add_service(MediaServiceServer::new(MediaServiceImpl::new(
            &configuration.audio,
        )))
        .add_service(AudioServiceServer::new(AudioServiceImpl::default()))
        .serve(addr)
        .await?;

    warn!("gRPC server stopped");
    Ok(())
}

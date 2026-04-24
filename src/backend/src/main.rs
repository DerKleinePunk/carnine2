use anyhow::Result;
use tonic::{transport::Server, Request, Response, Status};
use tracing::{info, warn};
use tracing_appender::rolling;
use tracing_subscriber::prelude::*;

pub mod carnine {
    tonic::include_proto!("carnine");
}

use carnine::{
    carnine_service_server::{CarnineService, CarnineServiceServer},
    CanDataRequest, CanDataResponse, CanData, CommandRequest, CommandResponse,
};

#[derive(Debug, Default)]
pub struct CarnineServiceImpl;

#[tonic::async_trait]
impl CarnineService for CarnineServiceImpl {
    async fn get_can_data(
        &self,
        request: Request<CanDataRequest>,
    ) -> Result<Response<CanDataResponse>, Status> {
        let req = request.into_inner();
        info!("Received CAN data request for sensor: {}", req.sensor_id);

        // Mock data for testing
        let data = vec![
            CanData {
                sensor_id: req.sensor_id.clone(),
                value: 42.0,
                timestamp: chrono::Utc::now().timestamp(),
            },
        ];

        let response = CanDataResponse { data };
        Ok(Response::new(response))
    }

    async fn send_command(
        &self,
        request: Request<CommandRequest>,
    ) -> Result<Response<CommandResponse>, Status> {
        let req = request.into_inner();
        info!("Received command: {} with params: {}", req.command, req.parameters);

        // Mock response
        let response = CommandResponse {
            success: true,
            message: format!("Command '{}' executed successfully", req.command),
        };
        Ok(Response::new(response))
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    std::fs::create_dir_all("logs")?;
    let file_appender = rolling::never("logs", "backend.log");
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
        .with(tracing_subscriber::EnvFilter::new("info"))
        .with(console_layer)
        .with(file_layer)
        .init();

    info!("carnine backend bootstrap started");

    let addr = "[::1]:50051".parse()?; // Use TCP for testing with Flutter
    let carnine_service = CarnineServiceImpl::default();

    info!("Starting gRPC server on {}", addr);
    Server::builder()
        .add_service(CarnineServiceServer::new(carnine_service))
        .serve(addr)
        .await?;

    warn!("gRPC server stopped");
    Ok(())
}

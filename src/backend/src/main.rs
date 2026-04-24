use anyhow::Result;
use tracing::{info, warn};

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter("info")
        .with_target(false)
        .compact()
        .init();

    info!("carnine backend bootstrap started");
    info!("waiting for shutdown signal");

    tokio::signal::ctrl_c().await?;
    warn!("shutdown signal received");

    Ok(())
}

use std::env;
use std::time::Duration;

use anyhow::{bail, Context, Result};
use tonic::transport::Channel;

pub mod carnine {
    tonic::include_proto!("carnine");
}

use carnine::{media_service_client::MediaServiceClient, Empty, PlayRequest};

#[tokio::main]
async fn main() -> Result<()> {
    let endpoint = env::args()
        .nth(1)
        .unwrap_or_else(|| "http://[::1]:50051".to_string());
    let command = env::args().nth(2).context(
        "usage: media_grpc_client [endpoint] <version|state|play|pause|resume|stop|smoke> [media-path]",
    )?;
    let mut client = MediaServiceClient::<Channel>::connect(endpoint.clone())
        .await
        .with_context(|| format!("failed to connect to {endpoint}"))?;

    match command.as_str() {
        "version" => {
            let response = client.get_service_version(Empty {}).await?.into_inner();
            println!(
                "version {}.{}.{}",
                response.major, response.minor, response.patch
            );
        }
        "state" => print_state(&mut client).await?,
        "play" => {
            let media_path = env::args().nth(3).context("play requires a media path")?;
            let response = client.play(PlayRequest { media_path }).await?.into_inner();
            println!("{}: {}", response.success, response.message);
        }
        "pause" => send_pause(&mut client).await?,
        "resume" => send_play(&mut client, String::new()).await?,
        "stop" => send_stop(&mut client).await?,
        "smoke" => smoke_test(&mut client).await?,
        unknown => bail!("unknown command: {unknown}"),
    }
    Ok(())
}

async fn send_play(client: &mut MediaServiceClient<Channel>, media_path: String) -> Result<()> {
    let response = client.play(PlayRequest { media_path }).await?.into_inner();
    println!("{}: {}", response.success, response.message);
    Ok(())
}

async fn send_pause(client: &mut MediaServiceClient<Channel>) -> Result<()> {
    let response = client.pause(Empty {}).await?.into_inner();
    println!("{}: {}", response.success, response.message);
    Ok(())
}

async fn send_stop(client: &mut MediaServiceClient<Channel>) -> Result<()> {
    let response = client.stop(Empty {}).await?.into_inner();
    println!("{}: {}", response.success, response.message);
    Ok(())
}

async fn print_state(client: &mut MediaServiceClient<Channel>) -> Result<()> {
    let state = client.get_player_state(Empty {}).await?.into_inner();
    println!(
        "state={} media={} position_ms={} duration_ms={}",
        state.status, state.media_path, state.position_ms, state.duration_ms
    );
    Ok(())
}

async fn smoke_test(client: &mut MediaServiceClient<Channel>) -> Result<()> {
    let media_path = env::args().nth(3).context("smoke requires a media path")?;
    send_play(client, media_path).await?;
    tokio::time::sleep(Duration::from_secs(3)).await;
    send_pause(client).await?;
    tokio::time::sleep(Duration::from_secs(1)).await;
    send_play(client, String::new()).await?;
    tokio::time::sleep(Duration::from_secs(3)).await;
    send_stop(client).await
}

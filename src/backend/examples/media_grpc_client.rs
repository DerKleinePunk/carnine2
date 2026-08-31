use std::env;
use std::time::Duration;

use anyhow::{bail, Context, Result};
use futures_util::StreamExt;
use tonic::transport::Channel;

pub mod carnine {
    tonic::include_proto!("carnine");
}

use carnine::{
    audio_service_client::AudioServiceClient, media_service_client::MediaServiceClient, Empty,
    PlayPlaylistRequest, PlayQueueEntryRequest, PlayRequest, RescanMediaRequest,
};

#[tokio::main]
async fn main() -> Result<()> {
    let endpoint = env::args()
        .nth(1)
        .unwrap_or_else(|| "http://[::1]:50051".to_string());
    let command = env::args()
        .nth(2)
        .context("usage: media_grpc_client [endpoint] <command> [argument]")?;
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
        "playlist" => play_playlist(&mut client).await?,
        "queue-entry" => play_queue_entry(&mut client).await?,
        "player-events" => stream_player_events(&mut client).await?,
        "library-events" => stream_library_events(&mut client).await?,
        "library-smoke" => library_event_smoke(&endpoint).await?,
        "audio-events" => stream_audio_events(&endpoint).await?,
        "rescan" => rescan(&mut client).await?,
        "event-smoke" => event_smoke(&endpoint).await?,
        "smoke" => smoke_test(&mut client).await?,
        unknown => bail!("unknown command: {unknown}"),
    }
    Ok(())
}

async fn play_playlist(client: &mut MediaServiceClient<Channel>) -> Result<()> {
    let playlist_id = env::args()
        .nth(3)
        .context("playlist requires a playlist id")?
        .parse::<u64>()?;
    let response = client
        .play_playlist(PlayPlaylistRequest { playlist_id })
        .await?
        .into_inner();
    println!("{}: {}", response.success, response.message);
    Ok(())
}

async fn play_queue_entry(client: &mut MediaServiceClient<Channel>) -> Result<()> {
    let index = env::args()
        .nth(3)
        .context("queue-entry requires a zero-based queue index")?
        .parse::<u32>()?;
    let response = client
        .play_queue_entry(PlayQueueEntryRequest { index })
        .await?
        .into_inner();
    println!("{}: {}", response.success, response.message);
    Ok(())
}

async fn stream_player_events(client: &mut MediaServiceClient<Channel>) -> Result<()> {
    let count = event_count(1)?;
    let mut stream = client.stream_player_events(Empty {}).await?.into_inner();
    read_events(&mut stream, count, |event| {
        println!("player event={} message={}", event.event, event.message);
        if let Some(state) = event.state {
            println!(
                "  state={} media={} position_ms={}",
                state.status, state.media_path, state.position_ms
            );
        }
    })
    .await
}

async fn stream_library_events(client: &mut MediaServiceClient<Channel>) -> Result<()> {
    let count = event_count(1)?;
    let mut stream = client.stream_library_events(Empty {}).await?.into_inner();
    read_events(&mut stream, count, |event| {
        println!(
            "library event={} scan_id={} processed={} imported={} path={} message={}",
            event.event, event.scan_id, event.processed, event.imported, event.path, event.message
        );
    })
    .await
}

async fn stream_audio_events(endpoint: &str) -> Result<()> {
    let count = event_count(1)?;
    let mut client = AudioServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let mut stream = client.stream_audio_events(Empty {}).await?.into_inner();
    read_events(&mut stream, count, |event| {
        println!("audio event={} message={}", event.event, event.message);
    })
    .await
}

async fn library_event_smoke(endpoint: &str) -> Result<()> {
    let mut event_client = MediaServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let mut action_client = MediaServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let mut stream = event_client
        .stream_library_events(Empty {})
        .await?
        .into_inner();
    action_client.rescan_media(RescanMediaRequest {}).await?;
    println!("rescan started");
    while let Some(event) = stream.message().await? {
        println!("library event={} scan_id={}", event.event, event.scan_id);
        if event.event == "scan_completed" {
            break;
        }
    }
    Ok(())
}

async fn event_smoke(endpoint: &str) -> Result<()> {
    let media_path = env::args()
        .nth(3)
        .context("event-smoke requires a media path")?;
    let mut event_client = MediaServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let mut action_client = MediaServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let mut stream = event_client
        .stream_player_events(Empty {})
        .await?
        .into_inner();
    send_play(&mut action_client, media_path).await?;
    read_events(&mut stream, 2, |event| {
        println!("player event={} message={}", event.event, event.message);
    })
    .await
}

async fn rescan(client: &mut MediaServiceClient<Channel>) -> Result<()> {
    let mut stream = client
        .rescan_media(RescanMediaRequest {})
        .await?
        .into_inner();
    while let Some(event) = stream.message().await? {
        println!("library event={} scan_id={}", event.event, event.scan_id);
    }
    Ok(())
}

async fn read_events<S, E, F>(stream: &mut S, count: usize, mut print: F) -> Result<()>
where
    S: futures_util::Stream<Item = Result<E, tonic::Status>> + Unpin,
    F: FnMut(E),
{
    let mut received = 0;
    while received < count {
        let Some(event) = stream.next().await else {
            bail!("event stream ended after {received} events");
        };
        print(event?);
        received += 1;
    }
    Ok(())
}

fn event_count(default: usize) -> Result<usize> {
    Ok(env::args()
        .nth(3)
        .map(|value| value.parse())
        .transpose()?
        .unwrap_or(default))
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
        "state={} media={} position_ms={} duration_ms={} playlist_id={}",
        state.status, state.media_path, state.position_ms, state.duration_ms, state.playlist_id
    );
    Ok(())
}

async fn smoke_test(client: &mut MediaServiceClient<Channel>) -> Result<()> {
    let media_path = env::args().nth(3).context("smoke requires a media path")?;
    send_play(client, media_path).await?;
    tokio::time::sleep(Duration::from_secs(3)).await;
    send_pause(client).await?;
    tokio::time::sleep(Duration::from_secs(5)).await;
    send_play(client, String::new()).await?;
    tokio::time::sleep(Duration::from_secs(3)).await;
    send_stop(client).await
}

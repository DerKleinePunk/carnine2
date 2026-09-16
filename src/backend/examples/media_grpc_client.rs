use std::env;
use std::time::Duration;

use anyhow::{bail, Context, Result};
use futures_util::StreamExt;
use tonic::transport::Channel;

pub mod carnine {
    tonic::include_proto!("carnine");
}

use carnine::{
    audio_service_client::AudioServiceClient, get_cover_art_request::Target as CoverArtTarget,
    media_service_client::MediaServiceClient, AddPlaylistEntryRequest, CreatePlaylistRequest,
    Empty, GetCoverArtRequest, GetPlaylistRequest, ImportMusicVolumeRequest, LibraryEventType,
    PlayPlaylistRequest, PlayQueueEntryRequest, PlayRequest, RepeatMode, RescanMediaRequest,
    SearchMediaRequest, SetRepeatModeRequest, SetShuffleModeRequest,
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
        "import" => import_music_volume(&mut client).await?,
        "smoke" => smoke_test(&mut client).await?,
        "search" => search_media(&mut client).await?,
        "create-playlist" => create_playlist(&mut client).await?,
        "list-playlists" => list_playlists(&mut client).await?,
        "add-playlist-entry" => add_playlist_entry(&mut client).await?,
        "get-playlist" => get_playlist(&mut client).await?,
        "cover-art" => get_cover_art(&mut client).await?,
        "repeat" => set_repeat_mode(&mut client).await?,
        "shuffle" => set_shuffle_mode(&mut client).await?,
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

async fn search_media(client: &mut MediaServiceClient<Channel>) -> Result<()> {
    let query = env::args().nth(3).unwrap_or_default();
    let items = client
        .search_media(SearchMediaRequest { query })
        .await?
        .into_inner()
        .items;
    for item in items {
        println!(
            "media id={} title={} artist={} duration_ms={} status={} has_cover_art={}",
            item.id, item.title, item.artist, item.duration_ms, item.status, item.has_cover_art
        );
    }
    Ok(())
}

async fn create_playlist(client: &mut MediaServiceClient<Channel>) -> Result<()> {
    let name = env::args()
        .nth(3)
        .context("create-playlist requires a playlist name")?;
    let playlist = client
        .create_playlist(CreatePlaylistRequest { name })
        .await?
        .into_inner();
    println!("playlist id={} name={}", playlist.id, playlist.name);
    Ok(())
}

async fn list_playlists(client: &mut MediaServiceClient<Channel>) -> Result<()> {
    let playlists = client
        .list_playlists(Empty {})
        .await?
        .into_inner()
        .playlists;
    for playlist in playlists {
        println!(
            "playlist id={} name={} has_cover_art={}",
            playlist.id, playlist.name, playlist.has_cover_art
        );
    }
    Ok(())
}

async fn add_playlist_entry(client: &mut MediaServiceClient<Channel>) -> Result<()> {
    let playlist_id = env::args()
        .nth(3)
        .context("add-playlist-entry requires a playlist id")?
        .parse::<u64>()?;
    let media_id = env::args()
        .nth(4)
        .context("add-playlist-entry requires a media id")?
        .parse::<u64>()?;
    let entry = client
        .add_playlist_entry(AddPlaylistEntryRequest {
            playlist_id,
            media_id,
        })
        .await?
        .into_inner();
    println!(
        "entry id={} playlist_id={} media_id={} position={}",
        entry.id, entry.playlist_id, entry.media_id, entry.position
    );
    Ok(())
}

async fn get_playlist(client: &mut MediaServiceClient<Channel>) -> Result<()> {
    let playlist_id = env::args()
        .nth(3)
        .context("get-playlist requires a playlist id")?
        .parse::<u64>()?;
    let playlist = client
        .get_playlist(GetPlaylistRequest { playlist_id })
        .await?
        .into_inner();
    println!(
        "playlist id={} name={} has_cover_art={}",
        playlist.id, playlist.name, playlist.has_cover_art
    );
    for entry in playlist.entries {
        println!(
            "  entry id={} media_id={} position={}",
            entry.id, entry.media_id, entry.position
        );
    }
    Ok(())
}

async fn get_cover_art(client: &mut MediaServiceClient<Channel>) -> Result<()> {
    let kind = env::args()
        .nth(3)
        .context("cover-art requires a target: media|playlist")?;
    let id = env::args()
        .nth(4)
        .context("cover-art requires a media or playlist id")?
        .parse::<u64>()?;
    let target = match kind.as_str() {
        "media" => CoverArtTarget::MediaId(id),
        "playlist" => CoverArtTarget::PlaylistId(id),
        other => bail!("unknown cover-art target: {other} (expected media|playlist)"),
    };
    let response = client
        .get_cover_art(GetCoverArtRequest {
            target: Some(target),
        })
        .await?
        .into_inner();
    println!(
        "cover art bytes={} mime_type={}",
        response.data.len(),
        response.mime_type
    );
    if let Some(output_path) = env::args().nth(5) {
        std::fs::write(&output_path, &response.data)
            .with_context(|| format!("failed to write cover art to {output_path}"))?;
        println!("saved to {output_path}");
    }
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
            "library event={} scan_id={} processed={} imported={} path={} message={} \
             playlist_id={} playlist_name={}",
            event.event,
            event.scan_id,
            event.processed,
            event.imported,
            event.path,
            event.message,
            event.playlist_id,
            event.playlist_name
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
        if event.event == LibraryEventType::LibraryScanCompleted as i32 {
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

async fn import_music_volume(client: &mut MediaServiceClient<Channel>) -> Result<()> {
    let source_path = env::args()
        .nth(3)
        .context("import requires a mounted source path")?;
    let mut stream = client
        .import_music_volume(ImportMusicVolumeRequest { source_path })
        .await?
        .into_inner();
    while let Some(event) = stream.message().await? {
        println!(
            "import event={} processed={} imported={} matching_files={} path={} message={}",
            event.event,
            event.processed,
            event.imported,
            event.matching_files,
            event.path,
            event.message
        );
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
        "state={} media={} position_ms={} duration_ms={} playlist_id={} repeat_mode={:?} shuffle_enabled={}",
        state.status,
        state.media_path,
        state.position_ms,
        state.duration_ms,
        state.playlist_id,
        state.repeat_mode(),
        state.shuffle_enabled
    );
    Ok(())
}

async fn set_repeat_mode(client: &mut MediaServiceClient<Channel>) -> Result<()> {
    let mode = env::args()
        .nth(3)
        .context("repeat requires a mode: off|queue|track")?;
    let mode = match mode.as_str() {
        "off" => RepeatMode::RepeatOff,
        "queue" => RepeatMode::RepeatQueue,
        "track" => RepeatMode::RepeatTrack,
        other => bail!("unknown repeat mode: {other} (expected off|queue|track)"),
    };
    let response = client
        .set_repeat_mode(SetRepeatModeRequest { mode: mode as i32 })
        .await?
        .into_inner();
    println!("{}: {}", response.success, response.message);
    Ok(())
}

async fn set_shuffle_mode(client: &mut MediaServiceClient<Channel>) -> Result<()> {
    let enabled = env::args()
        .nth(3)
        .context("shuffle requires a state: on|off")?;
    let enabled = match enabled.as_str() {
        "on" => true,
        "off" => false,
        other => bail!("unknown shuffle state: {other} (expected on|off)"),
    };
    let response = client
        .set_shuffle_mode(SetShuffleModeRequest { enabled })
        .await?
        .into_inner();
    println!("{}: {}", response.success, response.message);
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

// The gRPC calls return tonic's `Status`, which clippy counts as a large
// `Err`; it is the API's type, not ours.
#![allow(clippy::result_large_err)]

use std::env;
use std::time::Duration;

use anyhow::{bail, Context, Result};
use futures_util::StreamExt;
use tonic::transport::Channel;

pub mod carnine {
    tonic::include_proto!("carnine");
}

use carnine::{
    audio_service_client::AudioServiceClient, camera_service_client::CameraServiceClient,
    control_service_client::ControlServiceClient, get_cover_art_request::Target as CoverArtTarget,
    media_service_client::MediaServiceClient, navigation_service_client::NavigationServiceClient,
    system_service_client::SystemServiceClient, AddPlaylistEntryRequest, AnnounceRequest,
    AnnouncementPriority, CameraNorm, CameraSettings, ComputeRouteRequest, CreatePlaylistRequest,
    DeletePlaylistRequest, DisplayBrightness, Empty, ExitPasswordRequest, FixState,
    GetCoverArtRequest, GetLocationNameRequest, GetPlaylistRequest, GetReplayRouteRequest,
    ImportMusicVolumeRequest, LatLon, LibraryEventType, NavigationStatus, PlayPlaylistRequest,
    PlayQueueEntryRequest, PlayRequest, PositionFix, PositionSourceKind, PowerSupplyState,
    PowerSupplyStatus, PrepareAnnouncementsRequest, RemovePlaylistEntryRequest,
    RenamePlaylistRequest, RepeatMode, RescanMediaRequest, Route, SearchMediaRequest,
    SearchPlacesRequest, SeekRequest, SetDisplayBrightnessRequest, SetExitPasswordRequest,
    SetRepeatModeRequest, SetShuffleModeRequest, SetTrackRecordingRequest, SetVoiceSettingsRequest,
    SetVolumeRequest, SystemMetrics, ThermalStatus, UiState, VoiceSettings,
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
        "seek" => seek(&mut client).await?,
        "player-events" => stream_player_events(&mut client).await?,
        "library-events" => stream_library_events(&mut client).await?,
        "library-smoke" => library_event_smoke(&endpoint).await?,
        "audio-events" => stream_audio_events(&endpoint).await?,
        "volume" => get_volume(&endpoint).await?,
        "set-volume" => set_volume(&endpoint).await?,
        "rescan" => rescan(&mut client).await?,
        "event-smoke" => event_smoke(&endpoint).await?,
        "import" => import_music_volume(&mut client).await?,
        "smoke" => smoke_test(&mut client).await?,
        "search" => search_media(&mut client).await?,
        "create-playlist" => create_playlist(&mut client).await?,
        "list-playlists" => list_playlists(&mut client).await?,
        "add-playlist-entry" => add_playlist_entry(&mut client).await?,
        "get-playlist" => get_playlist(&mut client).await?,
        "rename-playlist" => rename_playlist(&mut client).await?,
        "delete-playlist" => delete_playlist(&mut client).await?,
        "remove-playlist-entry" => remove_playlist_entry(&mut client).await?,
        "cover-art" => get_cover_art(&mut client).await?,
        "repeat" => set_repeat_mode(&mut client).await?,
        "shuffle" => set_shuffle_mode(&mut client).await?,
        "metrics" => get_system_metrics(&endpoint).await?,
        "metrics-stream" => stream_system_metrics(&endpoint).await?,
        "power-supply" => get_power_supply_status(&endpoint).await?,
        "brightness" => get_display_brightness(&endpoint).await?,
        "set-brightness" => set_display_brightness(&endpoint).await?,
        "power-supply-stream" => stream_power_supply_status(&endpoint).await?,
        "thermal" => get_thermal_status(&endpoint).await?,
        "thermal-stream" => stream_thermal_status(&endpoint).await?,
        "ui-state" => get_ui_state(&endpoint).await?,
        "save-ui-state" => save_ui_state(&endpoint).await?,
        "save-language" => save_language(&endpoint).await?,
        "save-follow-zoom" => save_follow_zoom(&endpoint).await?,
        "verify-exit-password" => verify_exit_password(&endpoint).await?,
        "set-exit-password" => set_exit_password(&endpoint).await?,
        "nav-status" => get_navigation_status(&endpoint).await?,
        "positions" => stream_positions(&endpoint).await?,
        "places" => search_places(&endpoint).await?,
        "location-name" => location_name(&endpoint).await?,
        "route" => compute_route(&endpoint).await?,
        "replay-route" => replay_route(&endpoint).await?,
        "track-recording" => set_track_recording(&endpoint).await?,
        "prepare-announcements" => prepare_announcements(&endpoint).await?,
        "announce" => announce(&endpoint).await?,
        "voice-settings" => get_voice_settings(&endpoint).await?,
        "set-voice-settings" => set_voice_settings(&endpoint).await?,
        "camera-settings" => get_camera_settings(&endpoint).await?,
        "save-camera-settings" => save_camera_settings(&endpoint).await?,
        "camera-devices" => list_camera_devices(&endpoint).await?,
        "controls" => list_controls(&endpoint).await?,
        "control-states" => stream_control_states(&endpoint).await?,
        "set-control" => set_control(&endpoint).await?,
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

async fn seek(client: &mut MediaServiceClient<Channel>) -> Result<()> {
    let delta_ms = env::args()
        .nth(3)
        .context("seek requires a delta in milliseconds, e.g. 30000 or -30000")?
        .parse::<i64>()?;
    let response = client.seek(SeekRequest { delta_ms }).await?.into_inner();
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
    print_playlist(&playlist);
    Ok(())
}

async fn rename_playlist(client: &mut MediaServiceClient<Channel>) -> Result<()> {
    let playlist_id = env::args()
        .nth(3)
        .context("rename-playlist requires a playlist id")?
        .parse::<u64>()?;
    let name = env::args()
        .nth(4)
        .context("rename-playlist requires a new name")?;
    let playlist = client
        .rename_playlist(RenamePlaylistRequest { playlist_id, name })
        .await?
        .into_inner();
    println!("playlist id={} name={}", playlist.id, playlist.name);
    Ok(())
}

async fn delete_playlist(client: &mut MediaServiceClient<Channel>) -> Result<()> {
    let playlist_id = env::args()
        .nth(3)
        .context("delete-playlist requires a playlist id")?
        .parse::<u64>()?;
    client
        .delete_playlist(DeletePlaylistRequest { playlist_id })
        .await?;
    println!("playlist id={playlist_id} deleted");
    Ok(())
}

async fn remove_playlist_entry(client: &mut MediaServiceClient<Channel>) -> Result<()> {
    let entry_id = env::args()
        .nth(3)
        .context("remove-playlist-entry requires an entry id")?
        .parse::<u64>()?;
    let playlist = client
        .remove_playlist_entry(RemovePlaylistEntryRequest { entry_id })
        .await?
        .into_inner();
    print_playlist(&playlist);
    Ok(())
}

fn print_playlist(playlist: &carnine::Playlist) {
    println!(
        "playlist id={} name={} has_cover_art={}",
        playlist.id, playlist.name, playlist.has_cover_art
    );
    for entry in &playlist.entries {
        println!(
            "  entry id={} media_id={} position={}",
            entry.id, entry.media_id, entry.position
        );
    }
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
        let name = LibraryEventType::try_from(event.event)
            .map(|kind| kind.as_str_name())
            .unwrap_or("?");
        println!(
            "library event={} ({name}) scan_id={} processed={} imported={} path={} message={} \
             source_label={} source_path={} matching_files={} playlist_id={} playlist_name={}",
            event.event,
            event.scan_id,
            event.processed,
            event.imported,
            event.path,
            event.message,
            event.source_label,
            event.source_path,
            event.matching_files,
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
        let name = carnine::AudioEventType::try_from(event.event)
            .map(|kind| kind.as_str_name())
            .unwrap_or("UNKNOWN");
        println!(
            "audio event={} ({name}) message={}",
            event.event, event.message
        );
    })
    .await
}

async fn get_volume(endpoint: &str) -> Result<()> {
    let mut client = AudioServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let response = client.get_volume(Empty {}).await?.into_inner();
    println!("volume percent={}", response.percent);
    Ok(())
}

/// The percent is on amixer's mapped scale since #65.
async fn set_volume(endpoint: &str) -> Result<()> {
    let percent = env::args()
        .nth(3)
        .context("set-volume requires a percent between 0 and 100")?
        .parse::<u32>()?;
    let mut client = AudioServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let response = client
        .set_volume(SetVolumeRequest { percent })
        .await?
        .into_inner();
    println!("volume percent={}", response.percent);
    Ok(())
}

async fn get_system_metrics(endpoint: &str) -> Result<()> {
    let mut client = SystemServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let metrics = client.get_system_metrics(Empty {}).await?.into_inner();
    print_system_metrics(&metrics);
    Ok(())
}

/// Prints the opening snapshot plus as many pushed samples as requested
/// (default 1). With the stock 30 s cadence, `metrics-stream 3` runs for about
/// a minute.
async fn stream_system_metrics(endpoint: &str) -> Result<()> {
    let count = event_count(1)?;
    let mut client = SystemServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let mut stream = client.stream_system_metrics(Empty {}).await?.into_inner();
    read_events(&mut stream, count, |metrics| {
        print_system_metrics(&metrics);
    })
    .await
}

async fn get_ui_state(endpoint: &str) -> Result<()> {
    let mut client = SystemServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let state = client.get_ui_state(Empty {}).await?.into_inner();
    println!(
        "last_page={} language={} map_follow_zoom={}",
        state.last_page(),
        state.language(),
        state
            .map_follow_zoom
            .map_or_else(|| "-".to_string(), |zoom| zoom.to_string())
    );
    Ok(())
}

/// `save-follow-zoom <0-22>`: zoom of the map while it follows the car; 0
/// goes back to the frontend's default.
async fn save_follow_zoom(endpoint: &str) -> Result<()> {
    let zoom: u32 = env::args()
        .nth(3)
        .context("usage: media_grpc_client [endpoint] save-follow-zoom <0-22>")?
        .parse()
        .context("the zoom is a whole number, 0 for the default")?;
    let mut client = SystemServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let response = client
        .save_ui_state(UiState {
            last_page: None,
            language: None,
            map_follow_zoom: Some(zoom),
        })
        .await?
        .into_inner();
    println!("{}: {}", response.success, response.message);
    Ok(())
}

fn print_camera_settings(settings: &CameraSettings) {
    println!(
        "device={} norm={} input={} width={}",
        settings.device(),
        settings.norm().as_str_name(),
        settings.input(),
        settings.width()
    );
}

async fn get_camera_settings(endpoint: &str) -> Result<()> {
    let mut client = CameraServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    print_camera_settings(&client.get_camera_settings(Empty {}).await?.into_inner());
    Ok(())
}

/// `save-camera-settings <device|-> [ntsc|pal|-] [input|-] [360|720|-]`: `-` or
/// a missing value keeps what is stored, e.g. `save-camera-settings - pal`.
async fn save_camera_settings(endpoint: &str) -> Result<()> {
    let value = |index| env::args().nth(index).filter(|value| value != "-");
    let norm = match value(4).as_deref() {
        None => None,
        Some("ntsc") => Some(CameraNorm::Ntsc as i32),
        Some("pal") => Some(CameraNorm::Pal as i32),
        Some(other) => bail!("norm must be ntsc or pal, got {other}"),
    };
    let input = value(5)
        .map(|input| input.parse::<u32>())
        .transpose()
        .context("input must be a number")?;
    let width = value(6)
        .map(|width| width.parse::<u32>())
        .transpose()
        .context("width must be a number")?;
    let mut client = CameraServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let settings = client
        .save_camera_settings(CameraSettings {
            device: value(3),
            norm,
            input,
            width,
        })
        .await?
        .into_inner();
    print_camera_settings(&settings);
    Ok(())
}

async fn list_camera_devices(endpoint: &str) -> Result<()> {
    let mut client = CameraServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let devices = client
        .list_camera_devices(Empty {})
        .await?
        .into_inner()
        .devices;
    if devices.is_empty() {
        println!("no camera devices");
    }
    for device in devices {
        let driver = if device.driver.is_empty() {
            "-"
        } else {
            &device.driver
        };
        println!("{} {} driver={driver}", device.path, device.name);
    }
    Ok(())
}

/// `save-ui-state <page>`; without a page it clears the saved one.
async fn save_ui_state(endpoint: &str) -> Result<()> {
    let last_page = env::args().nth(3).unwrap_or_default();
    let mut client = SystemServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let response = client
        .save_ui_state(UiState {
            last_page: Some(last_page),
            language: None,
            map_follow_zoom: None,
        })
        .await?
        .into_inner();
    println!("{}: {}", response.success, response.message);
    Ok(())
}

/// Argument `index`, or else the next line on stdin, so that a password need
/// not end up in the shell history.
fn argument_or_stdin(index: usize, what: &str) -> Result<String> {
    if let Some(value) = env::args().nth(index) {
        return Ok(value);
    }
    eprintln!("{what}:");
    let mut line = String::new();
    std::io::stdin()
        .read_line(&mut line)
        .with_context(|| format!("failed to read the {what}"))?;
    Ok(line.trim_end_matches(['\r', '\n']).to_string())
}

/// `verify-exit-password [password]` (#51): prints valid=true/false.
async fn verify_exit_password(endpoint: &str) -> Result<()> {
    let password = argument_or_stdin(3, "password")?;
    let mut client = SystemServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let response = client
        .verify_exit_password(ExitPasswordRequest { password })
        .await?
        .into_inner();
    println!("valid={}", response.valid);
    Ok(())
}

/// `set-exit-password [current] [new]` (#51); missing ones are read from
/// stdin, one per line.
async fn set_exit_password(endpoint: &str) -> Result<()> {
    let current_password = argument_or_stdin(3, "current password")?;
    let new_password = argument_or_stdin(4, "new password")?;
    let mut client = SystemServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let response = client
        .set_exit_password(SetExitPasswordRequest {
            current_password,
            new_password,
        })
        .await?
        .into_inner();
    println!("{}: {}", response.success, response.message);
    Ok(())
}

/// `save-language <code>`, e.g. `save-language en`; without a code it clears
/// the saved language. The page saved last stays.
async fn save_language(endpoint: &str) -> Result<()> {
    let language = env::args().nth(3).unwrap_or_default();
    let mut client = SystemServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let response = client
        .save_ui_state(UiState {
            last_page: None,
            language: Some(language),
            map_follow_zoom: None,
        })
        .await?
        .into_inner();
    println!("{}: {}", response.success, response.message);
    Ok(())
}

async fn get_navigation_status(endpoint: &str) -> Result<()> {
    let mut client = NavigationServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let status = client.get_navigation_status(Empty {}).await?.into_inner();
    print_navigation_status(&status);
    Ok(())
}

fn print_navigation_status(status: &NavigationStatus) {
    let or_dash = |value: &str| {
        if value.is_empty() {
            "-".to_string()
        } else {
            value.to_string()
        }
    };
    println!(
        "routing_available={} source={:?} fix={:?} region={} track_recording={} track_file={} replay_lap={} demo_mode={}",
        status.routing_available,
        status.position_source(),
        status.fix_state(),
        or_dash(&status.map_region),
        match (
            status.track_recording_available,
            status.track_recording_enabled
        ) {
            (false, _) => "unavailable",
            (true, true) => "on",
            (true, false) => "off",
        },
        or_dash(&status.track_file),
        status.replay_lap,
        status.demo_mode,
    );
}

async fn set_track_recording(endpoint: &str) -> Result<()> {
    let enabled = env::args()
        .nth(3)
        .context("track-recording requires a state: on|off")?;
    let enabled = match enabled.as_str() {
        "on" => true,
        "off" => false,
        other => bail!("unknown track-recording state: {other} (expected on|off)"),
    };
    let mut client = NavigationServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let status = client
        .set_track_recording(SetTrackRecordingRequest { enabled })
        .await?
        .into_inner();
    print_navigation_status(&status);
    Ok(())
}

/// `prepare-announcements <text>...`: each argument is one sentence.
async fn prepare_announcements(endpoint: &str) -> Result<()> {
    let texts: Vec<String> = env::args().skip(3).collect();
    if texts.is_empty() {
        bail!("usage: media_grpc_client [endpoint] prepare-announcements <text>...");
    }
    let mut client = NavigationServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    client
        .prepare_announcements(PrepareAnnouncementsRequest { texts })
        .await?;
    println!("prepared");
    Ok(())
}

/// `announce <text> [info]`: speaks now; "info" gives way to turn instructions.
async fn announce(endpoint: &str) -> Result<()> {
    let text = env::args()
        .nth(3)
        .context("usage: media_grpc_client [endpoint] announce <text> [info]")?;
    let priority = match env::args().nth(4).as_deref() {
        None | Some("maneuver") => AnnouncementPriority::Maneuver,
        Some("info") => AnnouncementPriority::Info,
        Some(other) => bail!("unknown priority: {other} (expected maneuver|info)"),
    };
    let mut client = NavigationServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    client
        .announce(AnnounceRequest {
            text,
            priority: priority as i32,
        })
        .await?;
    println!("announced");
    Ok(())
}

fn print_voice_settings(settings: &VoiceSettings) {
    println!(
        "available={} enabled={} volume={}% music_under={}% voice={}",
        settings.available,
        settings.enabled,
        settings.volume_percent,
        settings.music_under_percent,
        settings.voice
    );
}

async fn get_voice_settings(endpoint: &str) -> Result<()> {
    let mut client = NavigationServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let settings = client.get_voice_settings(Empty {}).await?.into_inner();
    print_voice_settings(&settings);
    Ok(())
}

/// `set-voice-settings [on|off|-] [volume 0-100|-] [music_under 0-100]`.
async fn set_voice_settings(endpoint: &str) -> Result<()> {
    let usage = "usage: media_grpc_client [endpoint] set-voice-settings [on|off|-] [volume 0-100|-] [music_under 0-100]";
    let enabled = match env::args().nth(3).as_deref() {
        Some("on") => Some(true),
        Some("off") => Some(false),
        Some("-") | None => None,
        Some(other) => bail!("unknown state: {other}\n{usage}"),
    };
    let level = |index: usize| -> Result<Option<u32>> {
        match env::args().nth(index).as_deref() {
            Some("-") | None => Ok(None),
            Some(value) => Ok(Some(value.parse::<u32>().context(usage)?)),
        }
    };
    let volume_percent = level(4)?;
    let music_under_percent = level(5)?;
    let mut client = NavigationServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let settings = client
        .set_voice_settings(SetVoiceSettingsRequest {
            enabled,
            volume_percent,
            music_under_percent,
        })
        .await?
        .into_inner();
    print_voice_settings(&settings);
    Ok(())
}

fn parse_lat_lon(value: &str) -> Result<LatLon> {
    let (latitude, longitude) = value
        .split_once(',')
        .context("coordinates must be given as lat,lon")?;
    Ok(LatLon {
        latitude: latitude.trim().parse()?,
        longitude: longitude.trim().parse()?,
    })
}

/// `route <to lat,lon> [from lat,lon|-] [language|-] [heading]`: without a
/// start the backend routes from its current fix; heading is the course at
/// the start in degrees.
async fn compute_route(endpoint: &str) -> Result<()> {
    let destination = env::args().nth(3).context(
        "usage: media_grpc_client [endpoint] route <to lat,lon> [from lat,lon|-] [language|-] [heading]",
    )?;
    let origin = env::args()
        .nth(4)
        .filter(|value| value != "-")
        .map(|value| parse_lat_lon(&value))
        .transpose()?;
    // Course at the start in degrees, e.g. to try a reroute after a detour.
    let origin_heading_degrees = env::args()
        .nth(6)
        .map(|value| value.parse::<f64>())
        .transpose()
        .context("heading must be degrees, e.g. 184")?;
    let mut client = NavigationServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let route = client
        .compute_route(ComputeRouteRequest {
            origin,
            destination: Some(parse_lat_lon(&destination)?),
            language: env::args().nth(5).filter(|value| value != "-"),
            origin_heading_degrees,
        })
        .await?
        .into_inner();
    print_route(&route);
    Ok(())
}

/// `replay-route [language]`: the map-matched route of the running replay.
async fn replay_route(endpoint: &str) -> Result<()> {
    let mut client = NavigationServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let route = client
        .get_replay_route(GetReplayRouteRequest {
            language: env::args().nth(3),
        })
        .await?
        .into_inner();
    print_route(&route);
    Ok(())
}

fn print_route(route: &Route) {
    println!(
        "{} distance={:.1} km duration={:.0} min points={} maneuvers={} destination={}",
        route.route_id,
        route.distance_meters / 1000.0,
        route.duration_seconds / 60.0,
        route.geometry.len(),
        route.maneuvers.len(),
        if route.destination_name.is_empty() {
            "-"
        } else {
            &route.destination_name
        }
    );
    for maneuver in &route.maneuvers {
        println!(
            "  [{:>5}] type={:<2} {:>7.0} m  {}{}",
            maneuver.begin_shape_index,
            maneuver.r#type,
            maneuver.length_meters,
            maneuver.instruction,
            if maneuver.street_names.is_empty() {
                String::new()
            } else {
                format!(" ({})", maneuver.street_names.join(", "))
            }
        );
        for (label, text) in [
            ("alert", &maneuver.verbal_alert),
            ("pre", &maneuver.verbal_pre),
            ("post", &maneuver.verbal_post),
        ] {
            if let Some(text) = text {
                println!("           {label:<5} \"{text}\"");
            }
        }
    }
}

/// `places <query> [lat,lon]`: place search, optionally ranked around a point.
async fn search_places(endpoint: &str) -> Result<()> {
    let query = env::args()
        .nth(3)
        .context("usage: media_grpc_client [endpoint] places <query> [lat,lon]")?;
    let near = env::args()
        .nth(4)
        .map(|value| parse_lat_lon(&value))
        .transpose()?;
    let mut client = NavigationServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let response = client
        .search_places(SearchPlacesRequest {
            query,
            limit: 0,
            near,
        })
        .await?
        .into_inner();
    for place in &response.places {
        let (latitude, longitude) = place
            .location
            .as_ref()
            .map(|location| (location.latitude, location.longitude))
            .unwrap_or_default();
        println!(
            "{:<22} {:<40} {:<24} {latitude:.5},{longitude:.5} z{} {}",
            format!("{:?}", place.r#type()),
            place.name,
            place.area.as_deref().unwrap_or("-"),
            place.zoom,
            place.detail.as_deref().unwrap_or("")
        );
    }
    println!("{} hit(s)", response.places.len());
    Ok(())
}

/// `location-name [lat,lon]`: street, locality and district at a point, or
/// at the backend's current fix.
async fn location_name(endpoint: &str) -> Result<()> {
    let position = env::args()
        .nth(3)
        .map(|value| parse_lat_lon(&value))
        .transpose()?;
    let mut client = NavigationServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let name = client
        .get_location_name(GetLocationNameRequest { position })
        .await?
        .into_inner();
    println!("street:   {}", name.street.as_deref().unwrap_or("-"));
    println!("locality: {}", name.locality.as_deref().unwrap_or("-"));
    println!("district: {}", name.district.as_deref().unwrap_or("-"));
    Ok(())
}

/// Prints the current position plus as many updates as requested (default 5;
/// a replay or GPS mouse sends one per second).
async fn stream_positions(endpoint: &str) -> Result<()> {
    let count = event_count(5)?;
    let mut client = NavigationServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let mut stream = client.stream_positions(Empty {}).await?.into_inner();
    read_events(&mut stream, count, |fix| print_position(&fix)).await
}

fn print_position(fix: &PositionFix) {
    let optional = |value: Option<f64>, digits: usize| {
        value
            .map(|value| format!("{value:.digits$}"))
            .unwrap_or_else(|| "-".to_string())
    };
    let source = match fix.source() {
        PositionSourceKind::PositionSourceReplay => "replay",
        PositionSourceKind::PositionSourceSerial => "serial",
        _ => "none",
    };
    match (fix.fix_state(), &fix.location) {
        (FixState::Fix, Some(location)) => println!(
            "fix lat={:.6} lon={:.6} heading={} speed_mps={} accuracy_m={} time_ms={} source={source}",
            location.latitude,
            location.longitude,
            optional(fix.heading_degrees, 1),
            optional(fix.speed_mps, 2),
            optional(fix.accuracy_meters, 1),
            fix.timestamp_utc_ms
                .map(|value| value.to_string())
                .unwrap_or_else(|| "-".to_string()),
        ),
        _ => println!("no fix source={source}"),
    }
}

async fn get_power_supply_status(endpoint: &str) -> Result<()> {
    let mut client = SystemServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let status = client.get_power_supply_status(Empty {}).await?.into_inner();
    print_power_supply_status(&status);
    Ok(())
}

/// Prints the current status plus as many changes as requested (default 5),
/// e.g. while switching the ignition off and on at the supply.
async fn stream_power_supply_status(endpoint: &str) -> Result<()> {
    let count = event_count(5)?;
    let mut client = SystemServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let mut stream = client
        .stream_power_supply_status(Empty {})
        .await?
        .into_inner();
    read_events(&mut stream, count, |status| {
        print_power_supply_status(&status)
    })
    .await
}

fn print_display_brightness(brightness: &DisplayBrightness) {
    println!(
        "configured={} available={} percent={}",
        brightness.configured, brightness.available, brightness.percent
    );
}

/// `brightness`: the display backlight as the options show it.
async fn get_display_brightness(endpoint: &str) -> Result<()> {
    let mut client = SystemServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let brightness = client.get_display_brightness(Empty {}).await?.into_inner();
    print_display_brightness(&brightness);
    Ok(())
}

/// `set-brightness <0-100>`: 0 is the dimmest the configuration allows.
async fn set_display_brightness(endpoint: &str) -> Result<()> {
    let percent = env::args()
        .nth(3)
        .context("set-brightness requires a percentage 0-100")?
        .parse::<u32>()?;
    let mut client = SystemServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let brightness = client
        .set_display_brightness(SetDisplayBrightnessRequest { percent })
        .await?
        .into_inner();
    print_display_brightness(&brightness);
    Ok(())
}

async fn get_thermal_status(endpoint: &str) -> Result<()> {
    let mut client = SystemServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let status = client.get_thermal_status(Empty {}).await?.into_inner();
    print_thermal_status(&status);
    Ok(())
}

/// Prints the current status plus as many changes as requested (default 5),
/// e.g. while the CPU heats up past the warn threshold and cools down again.
/// `controls`: the switches and sliders of the "Technik" page.
async fn list_controls(endpoint: &str) -> Result<()> {
    let mut client = ControlServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let list = client.get_controls(Empty {}).await?.into_inner();
    if list.controls.is_empty() {
        println!("no controls configured");
    }
    for control in list.controls {
        println!(
            "id={} type={:?} name={:?} min={} max={}",
            control.id,
            control.r#type(),
            control.name,
            control.min,
            control.max
        );
    }
    Ok(())
}

fn print_control_state(state: &carnine::ControlState) {
    let value = match state.value {
        Some(carnine::control_state::Value::On(on)) => format!("on={on}"),
        Some(carnine::control_state::Value::Level(level)) => format!("level={level}"),
        None => "value=-".to_string(),
    };
    println!("id={} {value} available={}", state.id, state.available);
}

/// `control-states [count]`: every state, then the changes.
async fn stream_control_states(endpoint: &str) -> Result<()> {
    let count = event_count(10)?;
    let mut client = ControlServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let mut stream = client.stream_control_states(Empty {}).await?.into_inner();
    read_events(&mut stream, count, |state| print_control_state(&state)).await
}

/// `set-control <id> on|off|<0-100>`.
async fn set_control(endpoint: &str) -> Result<()> {
    let id = env::args()
        .nth(3)
        .context("set-control needs an id and on, off or a level 0-100")?;
    let value = match env::args().nth(4).as_deref() {
        Some("on") => carnine::set_control_state_request::Value::On(true),
        Some("off") => carnine::set_control_state_request::Value::On(false),
        Some(level) => carnine::set_control_state_request::Value::Level(
            level
                .parse()
                .with_context(|| format!("{level} is neither on, off nor a level 0-100"))?,
        ),
        None => bail!("set-control needs on, off or a level 0-100"),
    };
    let mut client = ControlServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let state = client
        .set_control_state(carnine::SetControlStateRequest {
            id,
            value: Some(value),
        })
        .await?
        .into_inner();
    print_control_state(&state);
    Ok(())
}

async fn stream_thermal_status(endpoint: &str) -> Result<()> {
    let count = event_count(5)?;
    let mut client = SystemServiceClient::<Channel>::connect(endpoint.to_string()).await?;
    let mut stream = client.stream_thermal_status(Empty {}).await?.into_inner();
    read_events(&mut stream, count, |status| print_thermal_status(&status)).await
}

fn print_thermal_status(status: &ThermalStatus) {
    println!(
        "overheated={} temperature={} warn={:.1}C clear={:.1}C changed_at_unix_ms={}",
        status.overheated,
        status
            .cpu_temperature_celsius
            .map(|celsius| format!("{celsius:.1}C"))
            .unwrap_or_else(|| "-".to_string()),
        status.warn_celsius,
        status.clear_celsius,
        status.changed_at_unix_ms
    );
}

fn print_power_supply_status(status: &PowerSupplyStatus) {
    if !status.configured {
        println!("power supply not configured");
        return;
    }
    let state = match status.state() {
        PowerSupplyState::Idle => "idle",
        PowerSupplyState::PowerOn => "power-on",
        PowerSupplyState::PiBoot => "pi-boot",
        PowerSupplyState::Run => "run",
        PowerSupplyState::PowerOff => "power-off",
        PowerSupplyState::Unspecified => "-",
    };
    let ignition = match status.ignition {
        Some(true) => "on",
        Some(false) => "off",
        None => "-",
    };
    println!(
        "connected={} ignition={ignition} state={state} voltage={} alive={}",
        status.connected,
        status
            .input_voltage_volts
            .map(|volts| format!("{volts:.1}V"))
            .unwrap_or_else(|| "-".to_string()),
        status
            .alive_count
            .map(|count| count.to_string())
            .unwrap_or_else(|| "-".to_string()),
    );
}

fn print_system_metrics(metrics: &SystemMetrics) {
    if metrics.sampled_at_unix_ms == 0 {
        println!("no sample taken yet");
        return;
    }
    let temperature = metrics
        .cpu_temperature_celsius
        .map(|value| format!("{value:.1} C"))
        .unwrap_or_else(|| "n/a".to_string());
    let usage = metrics
        .cpu_usage_percent
        .map(|value| format!("{value:.1} %"))
        .unwrap_or_else(|| "n/a".to_string());
    println!(
        "cpu temperature={temperature} usage={usage} load={:.2}/{:.2}/{:.2} cores={} uptime={}s",
        metrics.load_average_1m,
        metrics.load_average_5m,
        metrics.load_average_15m,
        metrics.cpu_count,
        metrics.uptime_seconds
    );
    for disk in &metrics.disks {
        println!(
            "disk path={} mount={} used={:.1} % available={:.2} GiB of {:.2} GiB",
            disk.path,
            disk.mount_point,
            disk.used_percent,
            disk.available_bytes as f64 / (1024.0 * 1024.0 * 1024.0),
            disk.total_bytes as f64 / (1024.0 * 1024.0 * 1024.0)
        );
    }
    if metrics.disks.is_empty() {
        println!("disk no sample taken yet");
    }
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

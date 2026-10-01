//! Settings of the reversing camera (the video grabber on the camera page).
//! The defaults come from `[camera]` in the configuration; what the settings
//! page saves is kept in the media database and overrides them. The frontend
//! only reads the settings in effect and hands them to the grabber.

use std::fs;
use std::path::{Path, PathBuf};

use tonic::{Request, Response, Status};
use tracing::{error, info};

use crate::carnine::{
    camera_service_server::CameraService, CameraDevice, CameraNorm, CameraSettings, Empty,
    ListCameraDevicesResponse,
};
use crate::config::{self, CameraConfig, CameraNormSetting, CAMERA_WIDTHS, MAX_CAMERA_INPUT};
use crate::database::{Database, SavedCameraSettings};

/// Where the kernel lists the V4L2 device nodes.
pub const VIDEO4LINUX_ROOT: &str = "/sys/class/video4linux";

/// Names of the SoC's own video nodes on a Raspberry Pi (codec, ISP, HEVC
/// decoder), which no camera is ever on.
const SOC_NODE_PREFIXES: [&str; 2] = ["bcm2835-", "rpi-"];

pub struct CameraServiceImpl {
    database_path: PathBuf,
    defaults: CameraConfig,
    video4linux_root: PathBuf,
}

impl CameraServiceImpl {
    pub fn new(database_path: PathBuf, defaults: CameraConfig, video4linux_root: PathBuf) -> Self {
        Self {
            database_path,
            defaults,
            video4linux_root,
        }
    }

    fn effective(&self, saved: &SavedCameraSettings) -> CameraSettings {
        let norm = saved
            .norm
            .as_deref()
            .and_then(norm_from_name)
            .unwrap_or_else(|| norm_from_setting(self.defaults.norm));
        CameraSettings {
            device: Some(
                saved
                    .device
                    .clone()
                    .unwrap_or_else(|| self.defaults.device.clone()),
            ),
            norm: Some(norm as i32),
            input: Some(saved.input.unwrap_or(self.defaults.input)),
            width: Some(saved.width.unwrap_or(self.defaults.width)),
        }
    }

    fn load(&self) -> Result<SavedCameraSettings, Status> {
        Database::open(&self.database_path)
            .and_then(|database| database.load_camera_settings())
            .map_err(|error| {
                error!(error = %error, "loading camera settings failed");
                Status::internal(error.to_string())
            })
    }
}

fn norm_from_setting(setting: CameraNormSetting) -> CameraNorm {
    match setting {
        CameraNormSetting::Ntsc => CameraNorm::Ntsc,
        CameraNormSetting::Pal => CameraNorm::Pal,
    }
}

/// The norm by the name it is stored under; `None` for anything else, so a
/// stored value this version does not know falls back to the default.
fn norm_from_name(name: &str) -> Option<CameraNorm> {
    match name {
        "ntsc" => Some(CameraNorm::Ntsc),
        "pal" => Some(CameraNorm::Pal),
        _ => None,
    }
}

fn norm_name(norm: CameraNorm) -> Option<&'static str> {
    match norm {
        CameraNorm::Ntsc => Some("ntsc"),
        CameraNorm::Pal => Some("pal"),
        CameraNorm::Unspecified => None,
    }
}

/// Checks a save request and turns it into what is stored.
fn validate(request: &CameraSettings) -> Result<SavedCameraSettings, Status> {
    if let Some(device) = &request.device {
        if !config::is_camera_device(device) {
            return Err(Status::invalid_argument(format!(
                "camera device must be /dev/video<n> or under /dev/v4l/: {device}"
            )));
        }
    }
    let norm = match request.norm {
        None => None,
        Some(value) => {
            let name = CameraNorm::try_from(value).ok().and_then(norm_name);
            Some(name.ok_or_else(|| {
                Status::invalid_argument(format!("camera norm must be NTSC or PAL, got {value}"))
            })?)
        }
    };
    if let Some(input) = request.input {
        if input > MAX_CAMERA_INPUT {
            return Err(Status::invalid_argument(format!(
                "camera input {input} is above {MAX_CAMERA_INPUT}"
            )));
        }
    }
    if let Some(width) = request.width {
        if !CAMERA_WIDTHS.contains(&width) {
            return Err(Status::invalid_argument(format!(
                "camera width must be one of {CAMERA_WIDTHS:?}, got {width}"
            )));
        }
    }
    Ok(SavedCameraSettings {
        device: request.device.clone(),
        norm: norm.map(str::to_string),
        input: request.input,
        width: request.width,
    })
}

/// The video nodes a camera can be on, sorted by node number: the first node
/// of each device (index 0; a UVC camera adds a metadata node with index 1)
/// and none of the SoC's own nodes.
pub fn list_camera_devices(video4linux_root: &Path) -> Vec<CameraDevice> {
    let Ok(entries) = fs::read_dir(video4linux_root) else {
        return Vec::new();
    };
    let mut devices: Vec<(u32, CameraDevice)> = entries
        .filter_map(|entry| {
            let entry = entry.ok()?;
            let node = entry.file_name().into_string().ok()?;
            let number: u32 = node.strip_prefix("video")?.parse().ok()?;
            let read = |file: &str| {
                fs::read_to_string(entry.path().join(file))
                    .map(|text| text.trim().to_string())
                    .ok()
            };
            let name = read("name").unwrap_or_default();
            if SOC_NODE_PREFIXES
                .iter()
                .any(|prefix| name.starts_with(prefix))
            {
                return None;
            }
            if read("index").is_some_and(|index| index != "0") {
                return None;
            }
            Some((
                number,
                CameraDevice {
                    path: format!("/dev/{node}"),
                    name,
                },
            ))
        })
        .collect();
    devices.sort_by_key(|(number, _)| *number);
    devices.into_iter().map(|(_, device)| device).collect()
}

#[tonic::async_trait]
impl CameraService for CameraServiceImpl {
    async fn get_camera_settings(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<CameraSettings>, Status> {
        Ok(Response::new(self.effective(&self.load()?)))
    }

    async fn save_camera_settings(
        &self,
        request: Request<CameraSettings>,
    ) -> Result<Response<CameraSettings>, Status> {
        let request = request.into_inner();
        info!(?request, "saving camera settings requested");
        let saved = validate(&request)?;
        Database::open(&self.database_path)
            .and_then(|database| database.save_camera_settings(&saved))
            .map_err(|error| {
                error!(error = %error, "saving camera settings failed");
                Status::internal(error.to_string())
            })?;
        Ok(Response::new(self.effective(&self.load()?)))
    }

    async fn list_camera_devices(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<ListCameraDevicesResponse>, Status> {
        Ok(Response::new(ListCameraDevicesResponse {
            devices: list_camera_devices(&self.video4linux_root),
        }))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    struct Scratch(PathBuf);

    impl Scratch {
        fn new(name: &str) -> Self {
            let path = std::env::temp_dir().join(format!(
                "carnine-camera-{name}-{}-{:?}",
                std::process::id(),
                std::thread::current().id()
            ));
            let _ = fs::remove_dir_all(&path);
            fs::create_dir_all(&path).unwrap();
            Self(path)
        }

        fn service(&self, defaults: CameraConfig) -> CameraServiceImpl {
            CameraServiceImpl::new(
                self.0.join("media.sqlite3"),
                defaults,
                self.0.join("video4linux"),
            )
        }

        /// A node under the scratch video4linux tree, as the kernel shows it.
        fn node(&self, node: &str, name: &str, index: &str) {
            let directory = self.0.join("video4linux").join(node);
            fs::create_dir_all(&directory).unwrap();
            fs::write(directory.join("name"), format!("{name}\n")).unwrap();
            fs::write(directory.join("index"), format!("{index}\n")).unwrap();
        }
    }

    impl Drop for Scratch {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    async fn get(service: &CameraServiceImpl) -> CameraSettings {
        service
            .get_camera_settings(Request::new(Empty {}))
            .await
            .unwrap()
            .into_inner()
    }

    async fn save(
        service: &CameraServiceImpl,
        settings: CameraSettings,
    ) -> Result<CameraSettings, Status> {
        service
            .save_camera_settings(Request::new(settings))
            .await
            .map(Response::into_inner)
    }

    /// Settings in effect with the default width of 360.
    fn settings(device: &str, norm: CameraNorm, input: u32) -> CameraSettings {
        CameraSettings {
            device: Some(device.to_string()),
            norm: Some(norm as i32),
            input: Some(input),
            width: Some(360),
        }
    }

    #[tokio::test]
    async fn defaults_until_something_is_saved() {
        let scratch = Scratch::new("defaults");
        let service = scratch.service(CameraConfig::default());

        assert_eq!(
            get(&service).await,
            settings("/dev/video0", CameraNorm::Ntsc, 0)
        );
    }

    #[tokio::test]
    async fn defaults_follow_the_configuration() {
        let scratch = Scratch::new("configured");
        let service = scratch.service(CameraConfig {
            device: "/dev/v4l/by-id/usb-grabber-video-index0".to_string(),
            norm: CameraNormSetting::Pal,
            input: 4,
            width: 720,
        });

        assert_eq!(
            get(&service).await,
            CameraSettings {
                width: Some(720),
                ..settings(
                    "/dev/v4l/by-id/usb-grabber-video-index0",
                    CameraNorm::Pal,
                    4
                )
            }
        );
    }

    #[tokio::test]
    async fn saved_fields_override_and_the_rest_stays() {
        let scratch = Scratch::new("partial");
        let service = scratch.service(CameraConfig::default());

        let answer = save(
            &service,
            CameraSettings {
                norm: Some(CameraNorm::Pal as i32),
                ..CameraSettings::default()
            },
        )
        .await
        .unwrap();
        assert_eq!(answer, settings("/dev/video0", CameraNorm::Pal, 0));

        let answer = save(
            &service,
            CameraSettings {
                input: Some(4),
                ..CameraSettings::default()
            },
        )
        .await
        .unwrap();
        assert_eq!(
            answer,
            settings("/dev/video0", CameraNorm::Pal, 4),
            "the norm saved before stays"
        );
        assert_eq!(get(&service).await, answer);
    }

    #[tokio::test]
    async fn the_width_is_saved_like_the_rest() {
        let scratch = Scratch::new("width");
        let service = scratch.service(CameraConfig::default());
        // Something saved before, so the width updates an existing row.
        save(
            &service,
            CameraSettings {
                norm: Some(CameraNorm::Pal as i32),
                ..CameraSettings::default()
            },
        )
        .await
        .unwrap();

        let answer = save(
            &service,
            CameraSettings {
                width: Some(720),
                ..CameraSettings::default()
            },
        )
        .await
        .unwrap();

        assert_eq!(
            answer,
            CameraSettings {
                width: Some(720),
                ..settings("/dev/video0", CameraNorm::Pal, 0)
            }
        );
        assert_eq!(get(&service).await, answer);
    }

    #[tokio::test]
    async fn saved_settings_survive_a_new_service() {
        let scratch = Scratch::new("restart");
        save(
            &scratch.service(CameraConfig::default()),
            settings("/dev/video2", CameraNorm::Pal, 1),
        )
        .await
        .unwrap();

        // As after a backend restart.
        let service = scratch.service(CameraConfig::default());
        assert_eq!(
            get(&service).await,
            settings("/dev/video2", CameraNorm::Pal, 1)
        );
    }

    #[tokio::test]
    async fn invalid_settings_are_refused_and_nothing_is_stored() {
        let scratch = Scratch::new("invalid");
        let service = scratch.service(CameraConfig::default());
        let refused = [
            CameraSettings {
                device: Some("/etc/passwd".to_string()),
                ..CameraSettings::default()
            },
            CameraSettings {
                device: Some("/dev/video".to_string()),
                ..CameraSettings::default()
            },
            CameraSettings {
                device: Some("/dev/v4l/../sda".to_string()),
                ..CameraSettings::default()
            },
            CameraSettings {
                norm: Some(CameraNorm::Unspecified as i32),
                ..CameraSettings::default()
            },
            CameraSettings {
                norm: Some(7),
                ..CameraSettings::default()
            },
            CameraSettings {
                input: Some(MAX_CAMERA_INPUT + 1),
                ..CameraSettings::default()
            },
            CameraSettings {
                width: Some(640),
                ..CameraSettings::default()
            },
            // One bad field spoils the whole request.
            CameraSettings {
                device: Some("/dev/video1".to_string()),
                input: Some(99),
                ..CameraSettings::default()
            },
        ];
        for request in refused {
            let status = save(&service, request.clone()).await.unwrap_err();
            assert_eq!(status.code(), tonic::Code::InvalidArgument, "{request:?}");
        }

        assert_eq!(
            get(&service).await,
            settings("/dev/video0", CameraNorm::Ntsc, 0)
        );
    }

    #[tokio::test]
    async fn an_unknown_stored_norm_falls_back_to_the_default() {
        let scratch = Scratch::new("unknown-norm");
        let service = scratch.service(CameraConfig::default());
        Database::open(&service.database_path)
            .unwrap()
            .save_camera_settings(&SavedCameraSettings {
                norm: Some("secam".to_string()),
                ..SavedCameraSettings::default()
            })
            .unwrap();

        assert_eq!(get(&service).await.norm, Some(CameraNorm::Ntsc as i32));
    }

    #[tokio::test]
    async fn lists_the_grabber_without_the_soc_nodes() {
        let scratch = Scratch::new("devices");
        // What a Pi 4 with a USB grabber and a UVC camera shows.
        scratch.node("video10", "bcm2835-codec-decode", "0");
        scratch.node("video13", "bcm2835-isp", "0");
        scratch.node("video19", "rpi-hevc-dec", "0");
        scratch.node("video0", "stk1160", "0");
        scratch.node("video2", "USB Camera: USB Camera", "0");
        scratch.node("video3", "USB Camera: USB Camera", "1");
        let service = scratch.service(CameraConfig::default());

        let devices = service
            .list_camera_devices(Request::new(Empty {}))
            .await
            .unwrap()
            .into_inner()
            .devices;

        assert_eq!(
            devices,
            vec![
                CameraDevice {
                    path: "/dev/video0".to_string(),
                    name: "stk1160".to_string(),
                },
                CameraDevice {
                    path: "/dev/video2".to_string(),
                    name: "USB Camera: USB Camera".to_string(),
                },
            ]
        );
    }

    #[test]
    fn no_devices_without_video4linux() {
        assert!(list_camera_devices(Path::new("/nonexistent/video4linux")).is_empty());
    }
}

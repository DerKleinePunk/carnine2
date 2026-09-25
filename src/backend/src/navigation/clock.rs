//! Sets the system clock from GPS time. A Raspberry Pi has no RTC; in a car
//! there is no network for NTP either, so without this the clock stays at
//! whatever systemd-timesyncd saved at the last shutdown.

use std::time::{SystemTime, UNIX_EPOCH};

use tracing::{info, warn};

/// Differences up to this are left alone: NMEA time has a resolution of a
/// second at best and arrives a little late on the serial line.
const TOLERANCE_MS: i64 = 2_000;

/// What to do with one GPS time.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Decision {
    /// Not enabled, or already handled.
    Nothing,
    /// NTP keeps the clock; GPS time is not needed.
    LeaveToNtp,
    /// The clock is within the tolerance.
    AlreadyRight,
    Set,
}

/// No GPS time before this is plausible (see `EARLIEST_GPS_DATE` in
/// `position`): a recording from years ago fed in for a test must never turn
/// the clock back.
const EARLIEST_CLOCK_MS: i64 = 1_767_225_600_000; // 2026-01-01T00:00:00Z

fn decide(enabled: bool, done: bool, synchronized: bool, gps_ms: i64, now_ms: i64) -> Decision {
    if !enabled || done || gps_ms < EARLIEST_CLOCK_MS {
        Decision::Nothing
    } else if synchronized {
        Decision::LeaveToNtp
    } else if (gps_ms - now_ms).abs() <= TOLERANCE_MS {
        Decision::AlreadyRight
    } else {
        Decision::Set
    }
}

/// Sets the clock once, from the first valid fix, and only while the kernel
/// reports it as not synchronized. Everything after that is NTP's job once a
/// network is there. Needs `CAP_SYS_TIME` (the service unit grants it);
/// without it, e.g. in WSL, it logs a warning once and the backend runs on.
#[derive(Debug)]
pub struct ClockSetter {
    enabled: bool,
    done: bool,
}

impl ClockSetter {
    pub fn new(enabled: bool) -> Self {
        Self {
            enabled,
            done: false,
        }
    }

    /// Hands in the (rollover-corrected) time of a valid fix.
    pub fn offer(&mut self, gps_ms: i64) {
        let Some(now_ms) = now_unix_ms() else {
            return;
        };
        match decide(
            self.enabled,
            self.done,
            kernel_clock_synchronized(),
            gps_ms,
            now_ms,
        ) {
            Decision::Nothing => {}
            Decision::LeaveToNtp => {
                self.done = true;
                info!("system clock is synchronized by NTP, GPS time not applied");
            }
            Decision::AlreadyRight => {
                self.done = true;
                info!("system clock matches GPS time");
            }
            Decision::Set => {
                self.done = true;
                match set_system_clock(gps_ms) {
                    Ok(()) => info!(
                        from = %format_ms(now_ms),
                        to = %format_ms(gps_ms),
                        "system clock set from GPS time"
                    ),
                    Err(err) => warn!(
                        error = %err,
                        "could not set the system clock from GPS time (needs CAP_SYS_TIME)"
                    ),
                }
            }
        }
    }
}

fn now_unix_ms() -> Option<i64> {
    let elapsed = SystemTime::now().duration_since(UNIX_EPOCH).ok()?;
    i64::try_from(elapsed.as_millis()).ok()
}

fn format_ms(ms: i64) -> String {
    chrono::DateTime::from_timestamp_millis(ms)
        .map(|time| time.format("%Y-%m-%d %H:%M:%S UTC").to_string())
        .unwrap_or_else(|| ms.to_string())
}

/// Whether the kernel considers the clock synchronized; systemd-timesyncd
/// clears `STA_UNSYNC` once it has an NTP answer. Reading needs no privilege.
fn kernel_clock_synchronized() -> bool {
    // SAFETY: timex is plain old data; modes = 0 makes adjtimex read-only.
    let mut timex: libc::timex = unsafe { std::mem::zeroed() };
    // SAFETY: timex is a valid, writable timex.
    let state = unsafe { libc::adjtimex(&mut timex) };
    state >= 0 && state != libc::TIME_ERROR && timex.status & libc::STA_UNSYNC == 0
}

fn set_system_clock(ms: i64) -> std::io::Result<()> {
    let time = libc::timespec {
        tv_sec: ms.div_euclid(1000) as libc::time_t,
        tv_nsec: (ms.rem_euclid(1000) * 1_000_000) as libc::c_long,
    };
    // SAFETY: time is a valid timespec for the duration of the call.
    if unsafe { libc::clock_settime(libc::CLOCK_REALTIME, &time) } == 0 {
        Ok(())
    } else {
        Err(std::io::Error::last_os_error())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const NOW: i64 = 1_790_348_271_000;

    #[test]
    fn sets_an_unsynchronized_clock_that_is_off() {
        assert_eq!(
            decide(true, false, false, NOW + 3_600_000, NOW),
            Decision::Set
        );
        assert_eq!(decide(true, false, false, NOW - 3_000, NOW), Decision::Set);
    }

    #[test]
    fn leaves_the_clock_alone_when_not_needed() {
        assert_eq!(
            decide(false, false, false, NOW + 3_600_000, NOW),
            Decision::Nothing
        );
        assert_eq!(
            decide(true, true, false, NOW + 3_600_000, NOW),
            Decision::Nothing
        );
        assert_eq!(
            decide(true, false, true, NOW + 3_600_000, NOW),
            Decision::LeaveToNtp
        );
        assert_eq!(
            decide(true, false, false, NOW + 1_500, NOW),
            Decision::AlreadyRight
        );
        // 2018 - an old recording, never a reason to turn the clock back.
        assert_eq!(
            decide(true, false, false, 1_525_184_102_000, NOW),
            Decision::Nothing
        );
    }

    #[test]
    fn earliest_clock_is_the_first_of_january_2026() {
        assert_eq!(
            chrono::DateTime::from_timestamp_millis(EARLIEST_CLOCK_MS)
                .unwrap()
                .to_rfc3339(),
            "2026-01-01T00:00:00+00:00"
        );
    }

    #[test]
    fn disabled_setter_never_touches_the_clock() {
        // Safe to run anywhere: disabled means no syscall that changes state.
        let mut setter = ClockSetter::new(false);
        setter.offer(0);
        assert!(!setter.done);
    }

    #[test]
    fn reading_the_sync_state_needs_no_privilege() {
        // Either answer is fine; it must not fail or need root.
        let _ = kernel_clock_synchronized();
    }
}

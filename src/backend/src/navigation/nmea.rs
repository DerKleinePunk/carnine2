//! Minimal NMEA 0183 parsing for the position source: `RMC` carries position,
//! course, speed and time; `GGA` adds the HDOP used for the accuracy estimate.

use chrono::{NaiveDate, NaiveTime};

const KNOTS_TO_MPS: f64 = 0.514_444;

/// Rough user-equivalent range error of a consumer receiver, in metres. The
/// accuracy estimate is HDOP times this; good enough to tell a solid fix from
/// a poor one, not a survey figure.
const UERE_METERS: f64 = 5.0;

/// One `RMC` sentence, the one a fix is built from.
#[derive(Debug, Clone, PartialEq)]
pub struct Rmc {
    /// `A` in the status field. `V` means the receiver has no valid position.
    pub valid: bool,
    pub latitude: f64,
    pub longitude: f64,
    pub speed_mps: Option<f64>,
    pub course_degrees: Option<f64>,
    pub time: Option<NaiveTime>,
    pub date: Option<NaiveDate>,
}

/// The parts of a sentence the position source uses.
#[derive(Debug, Clone, PartialEq)]
pub enum Sentence {
    Rmc(Rmc),
    Gga { hdop: Option<f64> },
}

/// Parses one line. Returns `None` for sentences that are not used, lines
/// with a wrong checksum, and anything malformed - a serial line can always
/// deliver a torn sentence, so none of this is an error.
pub fn parse_sentence(line: &str) -> Option<Sentence> {
    let body = checked_body(line.trim())?;
    let fields: Vec<&str> = body.split(',').collect();
    // Talker ids differ between receivers (GP, GN, GL ...); only the type matters.
    let kind = fields.first()?.get(2..)?;
    match kind {
        "RMC" => parse_rmc(&fields).map(Sentence::Rmc),
        "GGA" => Some(Sentence::Gga {
            hdop: fields.get(8).and_then(|value| value.parse::<f64>().ok()),
        }),
        _ => None,
    }
}

/// Estimated horizontal accuracy in metres for an HDOP value.
pub fn accuracy_from_hdop(hdop: f64) -> f64 {
    hdop * UERE_METERS
}

/// Strips `$` and `*hh`, returning the body only if the checksum matches.
fn checked_body(line: &str) -> Option<&str> {
    let line = line.strip_prefix('$')?;
    let (body, checksum) = line.rsplit_once('*')?;
    let expected = u8::from_str_radix(checksum.get(..2)?, 16).ok()?;
    let actual = body.bytes().fold(0u8, |acc, byte| acc ^ byte);
    (actual == expected).then_some(body)
}

fn parse_rmc(fields: &[&str]) -> Option<Rmc> {
    // $GPRMC,hhmmss.sss,A,ddmm.mmmm,N,dddmm.mmmm,E,knots,course,ddmmyy,...
    let valid = *fields.get(2)? == "A";
    let latitude = parse_coordinate(fields.get(3)?, fields.get(4)?, 2)?;
    let longitude = parse_coordinate(fields.get(5)?, fields.get(6)?, 3)?;
    Some(Rmc {
        valid,
        latitude,
        longitude,
        speed_mps: fields
            .get(7)
            .and_then(|value| value.parse::<f64>().ok())
            .map(|knots| knots * KNOTS_TO_MPS),
        course_degrees: fields.get(8).and_then(|value| value.parse::<f64>().ok()),
        time: fields.get(1).and_then(|value| parse_time(value)),
        date: fields.get(9).and_then(|value| parse_date(value)),
    })
}

/// `ddmm.mmmm` / `dddmm.mmmm` plus hemisphere to signed decimal degrees.
/// `degree_digits` is 2 for latitude, 3 for longitude - mixing them up moves
/// the position by degrees, which is how the map's simulator once ended up
/// outside its tiles.
fn parse_coordinate(value: &str, hemisphere: &str, degree_digits: usize) -> Option<f64> {
    if value.len() <= degree_digits {
        return None;
    }
    let degrees: f64 = value.get(..degree_digits)?.parse().ok()?;
    let minutes: f64 = value.get(degree_digits..)?.parse().ok()?;
    if minutes >= 60.0 {
        return None;
    }
    let magnitude = degrees + minutes / 60.0;
    match hemisphere {
        "N" | "E" => Some(magnitude),
        "S" | "W" => Some(-magnitude),
        _ => None,
    }
}

fn parse_time(value: &str) -> Option<NaiveTime> {
    let hours: u32 = value.get(0..2)?.parse().ok()?;
    let minutes: u32 = value.get(2..4)?.parse().ok()?;
    let seconds: f64 = value.get(4..)?.parse().ok()?;
    let whole = seconds.trunc() as u32;
    let millis = ((seconds - seconds.trunc()) * 1000.0).round() as u32;
    NaiveTime::from_hms_milli_opt(hours, minutes, whole, millis.min(999))
}

fn parse_date(value: &str) -> Option<NaiveDate> {
    let day: u32 = value.get(0..2)?.parse().ok()?;
    let month: u32 = value.get(2..4)?.parse().ok()?;
    let year: i32 = value.get(4..6)?.parse().ok()?;
    NaiveDate::from_ymd_opt(2000 + year, month, day)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_a_valid_rmc_with_course_and_speed() {
        let sentence = parse_sentence(
            "$GPRMC,141502.000,A,5024.5968,N,00921.8742,E,22.35,184.27,010518,,,A*5C",
        );
        let Some(Sentence::Rmc(rmc)) = sentence else {
            panic!("expected RMC, got {sentence:?}");
        };
        assert!(rmc.valid);
        assert!((rmc.latitude - 50.409_947).abs() < 1e-5);
        assert!((rmc.longitude - 9.364_570).abs() < 1e-5);
        assert!((rmc.speed_mps.unwrap() - 11.498).abs() < 1e-3);
        assert_eq!(rmc.course_degrees, Some(184.27));
        assert_eq!(rmc.time, NaiveTime::from_hms_milli_opt(14, 15, 2, 0));
        assert_eq!(rmc.date, NaiveDate::from_ymd_opt(2018, 5, 1));
    }

    #[test]
    fn keeps_an_invalid_rmc_as_no_fix_without_course() {
        let sentence =
            parse_sentence("$GPRMC,140906.149,V,5024.5978,N,00921.8766,E,,,010518,,,N*78");
        let Some(Sentence::Rmc(rmc)) = sentence else {
            panic!("expected RMC, got {sentence:?}");
        };
        assert!(!rmc.valid);
        assert_eq!(rmc.speed_mps, None);
        assert_eq!(rmc.course_degrees, None);
    }

    #[test]
    fn reads_hdop_from_gga_and_accepts_other_talkers() {
        let sentence = parse_sentence(
            "$GNGGA,141502.000,5024.5968,N,00921.8742,E,1,08,1.2,372.6,M,48.0,M,,*44",
        );
        assert_eq!(sentence, Some(Sentence::Gga { hdop: Some(1.2) }));
    }

    #[test]
    fn rejects_a_wrong_checksum_and_unused_sentences() {
        assert_eq!(
            parse_sentence("$GPRMC,140906.149,V,5024.5978,N,00921.8766,E,,,010518,,,N*00"),
            None
        );
        assert_eq!(parse_sentence("$GPGSA,A,1,,,,,,,,,,,,,,,*1E"), None);
        assert_eq!(parse_sentence("garbage"), None);
    }

    #[test]
    fn southern_and_western_hemispheres_are_negative() {
        assert!((parse_coordinate("3351.000", "S", 2).unwrap() + 33.85).abs() < 1e-9);
        assert!((parse_coordinate("15112.000", "W", 3).unwrap() + 151.2).abs() < 1e-9);
    }
}

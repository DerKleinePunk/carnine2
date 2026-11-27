//! Spoken lane hints (#159): a short sentence after a maneuver's spoken
//! text that says which lanes to take, e.g. "Die rechten zwei Spuren
//! benutzen." Only when the map is clear about it: the lanes that lead on
//! without a further change (`active`) lie side by side and are not all of
//! them. Lanes that are only `valid` need another change later, so they are
//! never named, as in the lane display. German and English; other route
//! languages get no hint. The options switch it (`VoiceSettings.lane_hints`).

use crate::carnine::{Lane, Maneuver};

/// The hint for `lanes` (left to right) in the route's `language` (BCP-47),
/// `None` where the lanes say nothing clear or the language has no texts.
pub fn lane_hint(lanes: &[Lane], language: &str) -> Option<String> {
    let texts = Texts::for_language(language)?;
    let total = lanes.len();
    if total < 2 {
        return None;
    }
    let active: Vec<usize> = lanes
        .iter()
        .enumerate()
        .filter(|(_, lane)| lane.active != 0)
        .map(|(index, _)| index)
        .collect();
    let (first, last) = (*active.first()?, *active.last()?);
    let count = active.len();
    if count == total || last - first + 1 != count {
        return None;
    }
    Some(if last == total - 1 {
        texts.edge(Side::Right, count)
    } else if first == 0 {
        texts.edge(Side::Left, count)
    } else if count == 1 {
        texts.single_inner(first, total)
    } else {
        texts.middle_lanes.to_string()
    })
}

/// Puts the hint after the maneuver's advance notice, where there is still
/// time to change lanes, or after the notice at the maneuver when it has no
/// advance one. Nothing changes without a hint or a spoken text.
pub fn add_lane_hint(maneuver: &mut Maneuver, language: &str) {
    let Some(hint) = lane_hint(&maneuver.lanes, language) else {
        return;
    };
    let text = match (&mut maneuver.verbal_alert, &mut maneuver.verbal_pre) {
        (Some(alert), _) => alert,
        (None, Some(pre)) => pre,
        (None, None) => return,
    };
    let trimmed = text.trim_end();
    *text = if trimmed.ends_with(['.', '!', '?']) {
        format!("{trimmed} {hint}")
    } else {
        format!("{trimmed}. {hint}")
    };
}

#[derive(Clone, Copy)]
enum Side {
    Left,
    Right,
}

struct Texts {
    one: [&'static str; 2],
    many: [&'static str; 2],
    numbers: [&'static str; 11],
    middle_lane: &'static str,
    middle_lanes: &'static str,
    ordinal: fn(usize, Side) -> String,
}

impl Texts {
    fn for_language(language: &str) -> Option<Self> {
        let primary = language.split(['-', '_']).next()?.to_ascii_lowercase();
        match primary.as_str() {
            "de" => Some(Self {
                one: ["Die linke Spur benutzen.", "Die rechte Spur benutzen."],
                many: [
                    "Die linken {} Spuren benutzen.",
                    "Die rechten {} Spuren benutzen.",
                ],
                numbers: [
                    "zwei", "drei", "vier", "fünf", "sechs", "sieben", "acht", "neun", "zehn",
                    "elf", "zwölf",
                ],
                middle_lane: "Die mittlere Spur benutzen.",
                middle_lanes: "Die mittleren Spuren benutzen.",
                ordinal: |position, side| {
                    let side = match side {
                        Side::Left => "links",
                        Side::Right => "rechts",
                    };
                    format!("Die {} Spur von {side} benutzen.", german_ordinal(position))
                },
            }),
            "en" => Some(Self {
                one: ["Use the left lane.", "Use the right lane."],
                many: ["Use the left {} lanes.", "Use the right {} lanes."],
                numbers: [
                    "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
                    "eleven", "twelve",
                ],
                middle_lane: "Use the middle lane.",
                middle_lanes: "Use the middle lanes.",
                ordinal: |position, side| {
                    let side = match side {
                        Side::Left => "left",
                        Side::Right => "right",
                    };
                    format!(
                        "Use the {} lane from the {side}.",
                        english_ordinal(position)
                    )
                },
            }),
            _ => None,
        }
    }

    fn edge(&self, side: Side, count: usize) -> String {
        let index = side as usize;
        if count == 1 {
            return self.one[index].to_string();
        }
        let number = self
            .numbers
            .get(count - 2)
            .map(|word| word.to_string())
            .unwrap_or_else(|| count.to_string());
        self.many[index].replace("{}", &number)
    }

    /// One lane away from both edges: the middle one of three, else counted
    /// from the nearer edge ("Die zweite Spur von links benutzen.").
    fn single_inner(&self, index: usize, total: usize) -> String {
        if total == 3 {
            return self.middle_lane.to_string();
        }
        let from_left = index + 1;
        let from_right = total - index;
        if from_left <= from_right {
            (self.ordinal)(from_left, Side::Left)
        } else {
            (self.ordinal)(from_right, Side::Right)
        }
    }
}

fn german_ordinal(position: usize) -> String {
    match position {
        2 => "zweite".to_string(),
        3 => "dritte".to_string(),
        4 => "vierte".to_string(),
        5 => "fünfte".to_string(),
        6 => "sechste".to_string(),
        other => format!("{other}."),
    }
}

fn english_ordinal(position: usize) -> String {
    match position {
        2 => "second".to_string(),
        3 => "third".to_string(),
        4 => "fourth".to_string(),
        5 => "fifth".to_string(),
        6 => "sixth".to_string(),
        other => format!("{other}th"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Lanes from a pattern, left to right: `a` active, `v` only valid,
    /// `-` neither.
    fn lanes(pattern: &str) -> Vec<Lane> {
        pattern
            .chars()
            .map(|lane| Lane {
                directions: 2,
                valid: u32::from(lane == 'v'),
                active: u32::from(lane == 'a'),
            })
            .collect()
    }

    fn hint(pattern: &str) -> Option<String> {
        lane_hint(&lanes(pattern), "de-DE")
    }

    #[test]
    fn lanes_at_an_edge_are_counted() {
        assert_eq!(hint("--a").as_deref(), Some("Die rechte Spur benutzen."));
        assert_eq!(
            hint("-aa").as_deref(),
            Some("Die rechten zwei Spuren benutzen.")
        );
        assert_eq!(
            hint("-aaaa").as_deref(),
            Some("Die rechten vier Spuren benutzen.")
        );
        assert_eq!(hint("a--").as_deref(), Some("Die linke Spur benutzen."));
        assert_eq!(
            hint("aa-").as_deref(),
            Some("Die linken zwei Spuren benutzen.")
        );
    }

    #[test]
    fn lanes_in_the_middle() {
        assert_eq!(hint("-a-").as_deref(), Some("Die mittlere Spur benutzen."));
        assert_eq!(
            hint("-aa-").as_deref(),
            Some("Die mittleren Spuren benutzen.")
        );
        assert_eq!(
            hint("-a--").as_deref(),
            Some("Die zweite Spur von links benutzen.")
        );
        assert_eq!(
            hint("---a-").as_deref(),
            Some("Die zweite Spur von rechts benutzen.")
        );
    }

    #[test]
    fn no_hint_where_the_lanes_say_nothing_clear() {
        assert_eq!(hint("aaa"), None, "all lanes lead on");
        assert_eq!(hint("a-a"), None, "apart");
        assert_eq!(hint("vv-"), None, "only valid: another change follows");
        assert_eq!(hint("---"), None, "no right lane");
        assert_eq!(hint("a"), None, "a single lane");
        assert_eq!(hint(""), None);
    }

    #[test]
    fn english_and_unknown_languages() {
        let lanes = lanes("-aa");
        assert_eq!(
            lane_hint(&lanes, "en-US").as_deref(),
            Some("Use the right two lanes.")
        );
        assert_eq!(
            lane_hint(&self::lanes("-a--"), "en").as_deref(),
            Some("Use the second lane from the left.")
        );
        assert_eq!(lane_hint(&lanes, "fr-FR"), None);
    }

    #[test]
    fn the_hint_follows_the_advance_notice() {
        let mut maneuver = Maneuver {
            verbal_alert: Some("In 300 Metern rechts halten auf B 8.".to_string()),
            verbal_pre: Some("Rechts halten auf B 8.".to_string()),
            lanes: lanes("-aa"),
            ..Default::default()
        };
        add_lane_hint(&mut maneuver, "de-DE");
        assert_eq!(
            maneuver.verbal_alert.as_deref(),
            Some("In 300 Metern rechts halten auf B 8. Die rechten zwei Spuren benutzen.")
        );
        assert_eq!(
            maneuver.verbal_pre.as_deref(),
            Some("Rechts halten auf B 8.")
        );
    }

    #[test]
    fn without_an_advance_notice_the_notice_at_the_maneuver_gets_it() {
        let mut maneuver = Maneuver {
            verbal_pre: Some("Links auf L 3037 abbiegen".to_string()),
            lanes: lanes("a-"),
            ..Default::default()
        };
        add_lane_hint(&mut maneuver, "de-DE");
        assert_eq!(
            maneuver.verbal_pre.as_deref(),
            Some("Links auf L 3037 abbiegen. Die linke Spur benutzen.")
        );
        let mut silent = Maneuver {
            lanes: lanes("a-"),
            ..Default::default()
        };
        add_lane_hint(&mut silent, "de-DE");
        assert_eq!(silent.verbal_alert, None);
        assert_eq!(silent.verbal_pre, None);
    }
}

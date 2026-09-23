use anyhow::{bail, Result};
use ringbuf::{traits::Consumer, HeapCons};

pub const CHANNELS: usize = 2;
const MAX_SOURCES: usize = 8;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SourceId(usize);

struct AudioSource {
    samples: Option<Vec<f32>>,
    consumer: Option<HeapCons<f32>>,
    position: usize,
    gain: f32,
    target_gain: f32,
    gain_step: f32,
    fade_frames_remaining: usize,
}

pub struct AudioMixer {
    sources: [Option<AudioSource>; MAX_SOURCES],
    fade_frames: usize,
}

impl AudioMixer {
    pub fn new(sample_rate: u32, fade_milliseconds: u32) -> Self {
        let fade_frames = (sample_rate as usize * fade_milliseconds as usize / 1_000).max(1);
        Self {
            sources: std::array::from_fn(|_| None),
            fade_frames,
        }
    }

    /// Mixes a ready buffer instead of a live stream. Production feeds the
    /// mixer through `add_stream_source`; this one serves the tests and the
    /// `cpal_mixer_spike` example, which is why the binary never calls it.
    #[allow(dead_code)]
    pub fn add_source(&mut self, samples: Vec<f32>, gain: f32) -> Result<SourceId> {
        if samples.is_empty() || !samples.len().is_multiple_of(CHANNELS) {
            bail!("audio source must contain non-empty stereo frames");
        }
        if !(0.0..=1.0).contains(&gain) {
            bail!("audio source gain must be between 0 and 1");
        }
        let slot = self
            .sources
            .iter()
            .position(Option::is_none)
            .ok_or_else(|| anyhow::anyhow!("audio mixer source limit reached"))?;
        self.sources[slot] = Some(AudioSource {
            samples: Some(samples),
            consumer: None,
            position: 0,
            gain,
            target_gain: gain,
            gain_step: 0.0,
            fade_frames_remaining: 0,
        });
        Ok(SourceId(slot))
    }

    pub fn add_stream_source(&mut self, consumer: HeapCons<f32>, gain: f32) -> Result<SourceId> {
        if !(0.0..=1.0).contains(&gain) {
            bail!("audio source gain must be between 0 and 1");
        }
        let slot = self
            .sources
            .iter()
            .position(Option::is_none)
            .ok_or_else(|| anyhow::anyhow!("audio mixer source limit reached"))?;
        self.sources[slot] = Some(AudioSource {
            samples: None,
            consumer: Some(consumer),
            position: 0,
            gain,
            target_gain: gain,
            gain_step: 0.0,
            fade_frames_remaining: 0,
        });
        Ok(SourceId(slot))
    }

    pub fn set_gain(&mut self, source_id: SourceId, target_gain: f32) -> Result<()> {
        if !(0.0..=1.0).contains(&target_gain) {
            bail!("audio source gain must be between 0 and 1");
        }
        let fade_frames = self.fade_frames;
        let source = self.source_mut(source_id)?;
        source.target_gain = target_gain;
        source.fade_frames_remaining = fade_frames;
        source.gain_step = (target_gain - source.gain) / fade_frames as f32;
        Ok(())
    }

    pub fn remove_source(&mut self, source_id: SourceId) -> Result<()> {
        self.source_mut(source_id)?;
        self.sources[source_id.0] = None;
        Ok(())
    }

    pub fn render(&mut self, output: &mut [f32]) -> Result<()> {
        if !output.len().is_multiple_of(CHANNELS) {
            bail!("output must contain complete stereo frames");
        }
        output.fill(0.0);
        for frame in output.chunks_exact_mut(CHANNELS) {
            for source in &mut self.sources {
                let Some(source) = source else {
                    continue;
                };
                advance_gain(source);
                if source.gain == 0.0 && source.fade_frames_remaining == 0 {
                    // Fully muted and not mid-fade (e.g. paused): stop pulling
                    // samples so a stream source's decoder sees real
                    // backpressure instead of having its ring buffer drained
                    // silently while "paused".
                    continue;
                }
                let (left, right) = if let Some(samples) = source.samples.as_ref() {
                    if source.position + CHANNELS > samples.len() {
                        continue;
                    }
                    let values = (samples[source.position], samples[source.position + 1]);
                    source.position += CHANNELS;
                    values
                } else if let Some(consumer) = source.consumer.as_mut() {
                    let left = consumer.try_pop().unwrap_or(0.0);
                    let right = consumer.try_pop().unwrap_or(left);
                    (left, right)
                } else {
                    continue;
                };
                frame[0] += left * source.gain;
                frame[1] += right * source.gain;
            }
            frame[0] = frame[0].clamp(-1.0, 1.0);
            frame[1] = frame[1].clamp(-1.0, 1.0);
        }
        for source in &mut self.sources {
            if source.as_ref().is_some_and(|source| {
                source
                    .samples
                    .as_ref()
                    .is_some_and(|samples| source.position >= samples.len())
            }) {
                *source = None;
            }
        }
        Ok(())
    }

    fn source_mut(&mut self, source_id: SourceId) -> Result<&mut AudioSource> {
        self.sources
            .get_mut(source_id.0)
            .and_then(Option::as_mut)
            .ok_or_else(|| anyhow::anyhow!("unknown audio source"))
    }
}

fn advance_gain(source: &mut AudioSource) {
    if source.fade_frames_remaining == 0 {
        return;
    }
    source.gain += source.gain_step;
    source.fade_frames_remaining -= 1;
    if source.fade_frames_remaining == 0 {
        source.gain = source.target_gain;
    }
}

#[cfg(test)]
mod tests {
    use super::{AudioMixer, CHANNELS};

    #[test]
    fn mixes_two_stereo_sources() {
        let mut mixer = AudioMixer::new(100, 100);
        mixer.add_source(vec![0.25, 0.5, 0.25, 0.5], 1.0).unwrap();
        mixer.add_source(vec![0.5, 0.25, 0.5, 0.25], 1.0).unwrap();
        let mut output = [0.0; 4];

        mixer.render(&mut output).unwrap();

        assert_eq!(output, [0.75, 0.75, 0.75, 0.75]);
    }

    #[test]
    fn fades_gain_without_changing_frame_alignment() {
        let mut mixer = AudioMixer::new(100, 100);
        let source_id = mixer
            .add_source(vec![1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0], 1.0)
            .unwrap();
        mixer.set_gain(source_id, 0.0).unwrap();
        let mut output = [0.0; 4];

        mixer.render(&mut output).unwrap();

        assert!(output
            .iter()
            .zip([0.9, 0.9, 0.8, 0.8])
            .all(|(actual, expected)| (actual - expected).abs() < 0.0001));
    }

    #[test]
    fn clamps_sum_to_valid_sample_range() {
        let mut mixer = AudioMixer::new(100, 100);
        mixer.add_source(vec![1.0, -1.0], 1.0).unwrap();
        mixer.add_source(vec![1.0, -1.0], 1.0).unwrap();
        let mut output = [0.0; CHANNELS];

        mixer.render(&mut output).unwrap();

        assert_eq!(output, [1.0, -1.0]);
    }

    #[test]
    fn removes_finished_sources_after_rendering() {
        let mut mixer = AudioMixer::new(100, 100);
        let source_id = mixer.add_source(vec![0.5, 0.5], 1.0).unwrap();
        let mut output = [0.0; CHANNELS];

        mixer.render(&mut output).unwrap();

        assert!(mixer.set_gain(source_id, 0.0).is_err());
    }

    #[test]
    fn rejects_incomplete_stereo_frames() {
        let mut mixer = AudioMixer::new(100, 100);
        assert!(mixer.add_source(vec![0.5], 1.0).is_err());
        assert!(mixer.render(&mut [0.0]).is_err());
    }

    // Regression test for issue #23: pause() only sets gain to 0.0, but render()
    // keeps calling try_pop() on the source's ring buffer regardless of gain.
    // That lets the decoder thread keep filling the (endlessly drained) buffer
    // while "paused", so resume audibly skips ahead by however long the pause
    // lasted. A muted stream source must stop being drained, not just muted.
    #[test]
    fn stream_source_is_not_drained_once_fully_muted() {
        use ringbuf::{
            traits::{Observer, Producer, Split},
            HeapRb,
        };

        // fade_frames = max(sample_rate * fade_ms / 1000, 1) = 1, so a single
        // render() call is enough to settle the gain fade all the way to 0.0.
        let mut mixer = AudioMixer::new(1, 1);
        let ring = HeapRb::<f32>::new(8);
        let (mut producer, consumer) = ring.split();
        for sample in [0.5_f32; 6] {
            producer.try_push(sample).unwrap();
        }
        let source_id = mixer.add_stream_source(consumer, 1.0).unwrap();
        mixer.set_gain(source_id, 0.0).unwrap();

        let mut output = [0.0; CHANNELS];
        // Settles the fade to gain == 0.0 (mirrors CpalPlayback::pause()).
        mixer.render(&mut output).unwrap();
        let occupied_once_muted = producer.occupied_len();

        // Real time passing while "paused": nothing should be pulled from the
        // source's ring buffer anymore now that it is fully muted.
        mixer.render(&mut output).unwrap();

        assert_eq!(
            producer.occupied_len(),
            occupied_once_muted,
            "a fully muted source must stop draining its ring buffer, not just its audible output"
        );
    }
}

use std::io::Read;
use std::path::Path;
use std::process::{Child, Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread::{self, JoinHandle};

use anyhow::{Context, Result};
use ringbuf::{
    traits::{Producer, Split},
    HeapCons, HeapProd, HeapRb,
};

const SOURCE_CHANNELS: usize = 2;
const BYTES_PER_SAMPLE: usize = 2;
const READ_BUFFER_BYTES: usize = 16 * 1024;

#[derive(Debug)]
pub struct ExternalPcmSource {
    stop_requested: Arc<AtomicBool>,
    child: Arc<Mutex<Option<Child>>>,
    decoder_thread: Option<JoinHandle<Result<u64>>>,
}

impl ExternalPcmSource {
    pub fn start(
        input_path: impl AsRef<Path>,
        sample_rate: u32,
        capacity_frames: usize,
    ) -> Result<(Self, HeapCons<f32>)> {
        let input_path = input_path.as_ref();
        let mut child = Command::new("ffmpeg")
            .args([
                "-hide_banner",
                "-loglevel",
                "error",
                "-nostdin",
                "-i",
                input_path
                    .to_str()
                    .context("audio path is not valid UTF-8")?,
                "-vn",
                "-f",
                "s16le",
                "-ar",
                &sample_rate.to_string(),
                "-ac",
                &SOURCE_CHANNELS.to_string(),
                "pipe:1",
            ])
            .stdout(Stdio::piped())
            .stderr(Stdio::inherit())
            .spawn()
            .with_context(|| format!("failed to start ffmpeg for {}", input_path.display()))?;
        let mut decoded_pcm = child.stdout.take().context("ffmpeg stdout was not piped")?;
        let child_control = Arc::new(Mutex::new(Some(child)));
        let stop_requested = Arc::new(AtomicBool::new(false));
        let ring = HeapRb::<f32>::new(capacity_frames * SOURCE_CHANNELS);
        let (mut producer, consumer) = ring.split();
        let thread_stop = Arc::clone(&stop_requested);
        let thread_child = Arc::clone(&child_control);
        let decoder_thread = thread::spawn(move || {
            let result = decode_into_ring(
                &mut decoded_pcm,
                &mut producer,
                &thread_stop,
                SOURCE_CHANNELS,
            );
            if let Some(mut child) = thread_child
                .lock()
                .unwrap_or_else(|poisoned| poisoned.into_inner())
                .take()
            {
                let _ = child.wait();
            }
            result
        });
        Ok((
            Self {
                stop_requested,
                child: child_control,
                decoder_thread: Some(decoder_thread),
            },
            consumer,
        ))
    }

    pub fn stop(mut self) -> Result<u64> {
        self.stop_requested.store(true, Ordering::Release);
        if let Some(mut child) = self
            .child
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .take()
        {
            let _ = child.kill();
            let _ = child.wait();
        }
        self.decoder_thread
            .take()
            .context("decoder thread was already stopped")?
            .join()
            .map_err(|_| anyhow::anyhow!("decoder thread panicked"))?
    }
}

impl Drop for ExternalPcmSource {
    fn drop(&mut self) {
        self.stop_requested.store(true, Ordering::Release);
        if let Some(mut child) = self
            .child
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .take()
        {
            let _ = child.kill();
        }
        if let Some(thread) = self.decoder_thread.take() {
            let _ = thread.join();
        }
    }
}

fn decode_into_ring(
    decoded_pcm: &mut impl Read,
    producer: &mut HeapProd<f32>,
    stop_requested: &AtomicBool,
    channels: usize,
) -> Result<u64> {
    let mut buffer = [0_u8; READ_BUFFER_BYTES];
    let mut pending = Vec::with_capacity(channels * BYTES_PER_SAMPLE);
    let mut sample_count = 0_u64;
    loop {
        if stop_requested.load(Ordering::Acquire) {
            break;
        }
        let bytes_read = decoded_pcm.read(&mut buffer)?;
        if bytes_read == 0 {
            break;
        }
        pending.extend_from_slice(&buffer[..bytes_read]);
        let frame_bytes = channels * BYTES_PER_SAMPLE;
        let complete_bytes = pending.len() / frame_bytes * frame_bytes;
        let complete_pcm = pending.drain(..complete_bytes).collect::<Vec<_>>();
        for frame in complete_pcm.chunks_exact(frame_bytes) {
            for sample in frame.chunks_exact(BYTES_PER_SAMPLE) {
                let value = i16::from_le_bytes([sample[0], sample[1]]) as f32 / i16::MAX as f32;
                while producer.try_push(value).is_err() {
                    if stop_requested.load(Ordering::Acquire) {
                        return Ok(sample_count);
                    }
                    thread::yield_now();
                }
                sample_count += 1;
            }
        }
    }
    Ok(sample_count)
}

#[cfg(test)]
mod tests {
    use std::io::Cursor;
    use std::sync::atomic::AtomicBool;

    use ringbuf::{
        traits::{Consumer, Split},
        HeapRb,
    };

    use super::decode_into_ring;

    #[test]
    fn decodes_interleaved_stereo_frames_without_reordering() {
        let pcm = [
            0x00, 0x40, 0x00, 0x20, // 0.5, 0.25
            0x00, 0x10, 0x00, 0x08, // 0.125, 0.0625
        ];
        let ring = HeapRb::<f32>::new(4);
        let (mut producer, mut consumer) = ring.split();

        let stop_requested = AtomicBool::new(false);
        let sample_count =
            decode_into_ring(&mut Cursor::new(pcm), &mut producer, &stop_requested, 2)
                .expect("PCM decoding should succeed");

        assert_eq!(sample_count, 4);
        let samples: Vec<f32> = (0..4).map(|_| consumer.try_pop().unwrap()).collect();
        assert!(samples
            .iter()
            .zip([0.5, 0.25, 0.125, 0.0625])
            .all(|(actual, expected)| (actual - expected).abs() < 0.0001));
    }
}

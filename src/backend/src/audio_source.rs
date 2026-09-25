use std::io::Read;
use std::path::Path;
use std::process::{Child, Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread::{self, JoinHandle};
use std::time::Duration;

use anyhow::{Context, Result};
use ringbuf::{
    traits::{Producer, Split},
    HeapCons, HeapProd, HeapRb,
};

const SOURCE_CHANNELS: usize = 2;
const BYTES_PER_SAMPLE: usize = 2;
const READ_BUFFER_BYTES: usize = 16 * 1024;
/// How long the decoder waits when the ring buffer is full. Sleeping rather
/// than spinning matters a lot here: the ring holds two seconds and FFmpeg
/// decodes far faster than realtime, so the buffer is full almost all the
/// time. A busy wait therefore burns a whole core for the entire track - and
/// on the Raspberry Pi that core is contended by the cpal output callback,
/// which runs as an ordinary SCHED_OTHER thread with a 25 ms deadline.
const RING_FULL_WAIT: Duration = Duration::from_millis(5);

#[derive(Debug)]
pub struct ExternalPcmSource {
    stop_requested: Arc<AtomicBool>,
    finished: Arc<AtomicBool>,
    child: Arc<Mutex<Option<Child>>>,
    decoder_thread: Option<JoinHandle<Result<u64>>>,
}

impl ExternalPcmSource {
    /// Starts FFmpeg decoding `input_path` from `position_ms` into the track.
    /// `-ss` before `-i` makes FFmpeg seek in the input rather than decode and
    /// discard everything up to that point; 0 starts at the beginning.
    pub fn start_at(
        input_path: impl AsRef<Path>,
        sample_rate: u32,
        capacity_frames: usize,
        position_ms: i64,
    ) -> Result<(Self, HeapCons<f32>)> {
        let input_path = input_path.as_ref();
        let mut arguments = vec![
            "-hide_banner".to_string(),
            "-loglevel".to_string(),
            "error".to_string(),
            "-nostdin".to_string(),
        ];
        if position_ms > 0 {
            arguments.push("-ss".to_string());
            arguments.push(format!("{}.{:03}", position_ms / 1000, position_ms % 1000));
        }
        arguments.extend([
            "-i".to_string(),
            input_path
                .to_str()
                .context("audio path is not valid UTF-8")?
                .to_string(),
            "-vn".to_string(),
            "-f".to_string(),
            "s16le".to_string(),
            "-ar".to_string(),
            sample_rate.to_string(),
            "-ac".to_string(),
            SOURCE_CHANNELS.to_string(),
            "pipe:1".to_string(),
        ]);
        let mut child = Command::new("ffmpeg")
            .args(&arguments)
            .stdout(Stdio::piped())
            .stderr(Stdio::inherit())
            .spawn()
            .with_context(|| format!("failed to start ffmpeg for {}", input_path.display()))?;
        let mut decoded_pcm = child.stdout.take().context("ffmpeg stdout was not piped")?;
        let child_control = Arc::new(Mutex::new(Some(child)));
        let stop_requested = Arc::new(AtomicBool::new(false));
        let finished = Arc::new(AtomicBool::new(false));
        let ring = HeapRb::<f32>::new(capacity_frames * SOURCE_CHANNELS);
        let (mut producer, consumer) = ring.split();
        let thread_stop = Arc::clone(&stop_requested);
        let thread_finished = Arc::clone(&finished);
        let thread_child = Arc::clone(&child_control);
        let decoder_thread = thread::spawn(move || {
            let result = decode_into_ring(
                &mut decoded_pcm,
                &mut producer,
                &thread_stop,
                &thread_finished,
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
                finished,
                child: child_control,
                decoder_thread: Some(decoder_thread),
            },
            consumer,
        ))
    }

    pub fn is_finished(&self) -> bool {
        self.finished.load(Ordering::Acquire)
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
    finished: &AtomicBool,
    channels: usize,
) -> Result<u64> {
    let mut buffer = [0_u8; READ_BUFFER_BYTES];
    let mut pending = Vec::with_capacity(channels * BYTES_PER_SAMPLE);
    let mut decoded = Vec::with_capacity(READ_BUFFER_BYTES / BYTES_PER_SAMPLE);
    let mut sample_count = 0_u64;
    loop {
        if stop_requested.load(Ordering::Acquire) {
            break;
        }
        let bytes_read = decoded_pcm.read(&mut buffer)?;
        if bytes_read == 0 {
            finished.store(true, Ordering::Release);
            break;
        }
        pending.extend_from_slice(&buffer[..bytes_read]);
        let frame_bytes = channels * BYTES_PER_SAMPLE;
        let complete_bytes = pending.len() / frame_bytes * frame_bytes;
        // frame_bytes is a multiple of BYTES_PER_SAMPLE, so walking the whole
        // range sample by sample keeps the interleaved channel order intact.
        decoded.clear();
        decoded.extend(
            pending[..complete_bytes]
                .as_chunks::<BYTES_PER_SAMPLE>()
                .0
                .iter()
                .map(|sample| i16::from_le_bytes(*sample) as f32 / i16::MAX as f32),
        );
        pending.drain(..complete_bytes);
        let mut offset = 0;
        while offset < decoded.len() {
            let pushed = producer.push_slice(&decoded[offset..]);
            offset += pushed;
            sample_count += pushed as u64;
            if offset < decoded.len() {
                if stop_requested.load(Ordering::Acquire) {
                    return Ok(sample_count);
                }
                thread::sleep(RING_FULL_WAIT);
            }
        }
    }
    Ok(sample_count)
}

#[cfg(test)]
mod tests {
    use std::io::Cursor;
    use std::sync::atomic::{AtomicBool, Ordering};
    use std::sync::Arc;
    use std::thread;
    use std::time::Duration;

    use ringbuf::{
        traits::{Consumer, Split},
        HeapRb,
    };

    use super::{decode_into_ring, ExternalPcmSource};

    #[test]
    fn start_at_decodes_only_the_rest_of_the_track() {
        const SAMPLE_RATE: u32 = 44_100;
        // The repository test track runs about 174.9 s.
        let (source, _consumer) = ExternalPcmSource::start_at(
            "../../resources/musik/1-Here We Go Now (Single Edit).mp3",
            SAMPLE_RATE,
            SAMPLE_RATE as usize * 10,
            170_000,
        )
        .expect("ffmpeg should start");
        let deadline = std::time::Instant::now() + Duration::from_secs(20);
        while !source.is_finished() && std::time::Instant::now() < deadline {
            thread::sleep(Duration::from_millis(20));
        }
        assert!(
            source.is_finished(),
            "the last seconds should decode quickly"
        );

        let seconds =
            source.stop().expect("decoder should stop") as f64 / (SAMPLE_RATE as f64 * 2.0);
        assert!(
            (4.0..6.0).contains(&seconds),
            "decoded {seconds:.2} s instead of the last ~4.9 s"
        );
    }

    #[test]
    fn decodes_interleaved_stereo_frames_without_reordering() {
        let pcm = [
            0x00, 0x40, 0x00, 0x20, // 0.5, 0.25
            0x00, 0x10, 0x00, 0x08, // 0.125, 0.0625
        ];
        let ring = HeapRb::<f32>::new(4);
        let (mut producer, mut consumer) = ring.split();

        let stop_requested = AtomicBool::new(false);
        let finished = AtomicBool::new(false);
        let sample_count = decode_into_ring(
            &mut Cursor::new(pcm),
            &mut producer,
            &stop_requested,
            &finished,
            2,
        )
        .expect("PCM decoding should succeed");

        assert_eq!(sample_count, 4);
        assert!(finished.load(std::sync::atomic::Ordering::Acquire));
        let samples: Vec<f32> = (0..4).map(|_| consumer.try_pop().unwrap()).collect();
        assert!(samples
            .iter()
            .zip([0.5, 0.25, 0.125, 0.0625])
            .all(|(actual, expected)| (actual - expected).abs() < 0.0001));
    }

    // Regression test for the busy wait measured on the Raspberry Pi on
    // 2026-09-22: the decoder thread sat at 99.9% CPU for the whole track
    // because it spun on thread::yield_now() whenever the ring was full.
    // FFmpeg decodes far faster than realtime, so a full ring is the normal
    // state, not an exception - the spin burned a core for minutes on end and
    // starved the cpal output callback, which runs without realtime priority
    // on the Pi. Measuring the thread's own CPU time is what tells a sleeping
    // wait apart from a spinning one; wall-clock time cannot.
    #[test]
    fn decoder_sleeps_instead_of_spinning_while_the_ring_is_full() {
        const MEASURED_WAIT: Duration = Duration::from_millis(300);

        // Four samples of capacity against a far larger source, and nothing
        // ever drains it: after the first push the decoder can only wait.
        let pcm = vec![0_u8; 64 * 1024];
        let ring = HeapRb::<f32>::new(4);
        let (mut producer, _consumer) = ring.split();
        let stop_requested = Arc::new(AtomicBool::new(false));
        let finished = Arc::new(AtomicBool::new(false));
        let thread_stop = Arc::clone(&stop_requested);
        let thread_finished = Arc::clone(&finished);

        let decoder = thread::spawn(move || {
            let before = thread_cpu_time();
            let _ = decode_into_ring(
                &mut Cursor::new(pcm),
                &mut producer,
                &thread_stop,
                &thread_finished,
                2,
            );
            thread_cpu_time() - before
        });

        thread::sleep(MEASURED_WAIT);
        stop_requested.store(true, Ordering::Release);
        let burned = decoder.join().expect("decoder thread should not panic");

        assert!(
            burned < MEASURED_WAIT / 5,
            "decoder burned {burned:?} of CPU while waiting {MEASURED_WAIT:?} on a full ring, \
             so it is busy waiting instead of sleeping"
        );
    }

    /// CPU time consumed by the calling thread. `Instant` measures wall clock
    /// and so cannot distinguish a thread that sleeps from one that spins.
    fn thread_cpu_time() -> Duration {
        let mut spec = libc::timespec {
            tv_sec: 0,
            tv_nsec: 0,
        };
        // SAFETY: writes into a timespec this call owns, with a constant clock id.
        let result = unsafe { libc::clock_gettime(libc::CLOCK_THREAD_CPUTIME_ID, &mut spec) };
        assert_eq!(result, 0, "clock_gettime(CLOCK_THREAD_CPUTIME_ID) failed");
        Duration::new(spec.tv_sec as u64, spec.tv_nsec as u32)
    }
}

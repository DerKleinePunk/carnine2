use anyhow::Result;

pub trait AudioEngine: Send + Sync {
    fn start(&self, input_path: &str) -> Result<Box<dyn Playback>>;

    fn shutdown(&self) -> Result<()> {
        Ok(())
    }

    fn start_at(&self, input_path: &str, position_ms: i64) -> Result<Box<dyn Playback>> {
        let _ = position_ms;
        self.start(input_path)
    }
}

pub trait Playback: Send {
    fn pause(&self) -> Result<()>;
    fn resume(&self) -> Result<()>;
    fn stop(self: Box<Self>) -> Result<()>;

    // True only once playback reached the track's natural end on its own,
    // never as a result of an explicit stop() — the auto-advance watcher
    // polls this to tell "track ended" apart from "user stopped it".
    fn is_finished(&self) -> bool {
        false
    }
}

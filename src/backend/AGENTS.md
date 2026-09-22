# AGENTS.md

## Build/Test Commands
- `cargo build` - Build the project
- `cargo run` - Run the application
- `cargo test` - Run all tests
- `cargo test <test_name>` - Run a specific test
- `cargo check` - Check code without building, use this before each build since it is a lot faster

## Code Style Guidelines
- Use `snake_case` for variables, functions, and modules
- Use `PascalCase` for types, structs, enums, and traits
- Prefer explicit types over `auto`/inference when clarity improves
- Use `anyhow::Result` for error handling with context
- Import organization: std first, external crates, then local modules
- Use `#[derive(Debug)]` on all structs and enums
- Prefer `match` over `if let` for complex pattern matching
- Use `const` for compile-time constants (e.g., `const MOVE_STEP: f32 = 40.0`)
- Use `static` with `LazyLock` for global state (e.g., `CONFIG`)
- Implement `Default` trait where appropriate
- Use `EnumString` derive for string-to-enum conversion
- Prefer `PathBuf` over `&str` for file paths
- Use `tokio::sync` primitives for async communication
- Structure modules with `mod.rs` files for organization
- Use the `debug!`, `info!` and `error!` from `tracing` for printing and logging

## Runtime Logging
- Every externally visible lifecycle operation must log both the request and
	its successful completion or failure.
- Audio sources use consistent events: `source_started`,
  `source_pause_requested`, `source_resume_requested`,
  `source_stop_requested`, `decoder_stopped`, and `source_removed`.
- Include structured context fields whenever available: `source_id`, media
	path, backend, sample rate, channel count, decoded sample count, and error.
- Log control paths and error callbacks, but never log from a real-time audio
	callback. The callback must remain allocation-free, non-blocking, and free
	of I/O.
- A stop operation is not complete until the decoder, source buffer, and output
	ownership have been released or an explicit failure has been logged.

## Audio Threading
- Never busy-wait anywhere in the audio path. A full source ring buffer is the
	normal state, not an exception: FFmpeg decodes far faster than realtime, so
	a decoder that spins on a full buffer spins for the entire track. On the Pi
	this starves the cpal output callback, which runs as an ordinary
	`SCHED_OTHER` thread with a 25 ms deadline and no realtime priority.
	Wait by sleeping or blocking, never with `thread::yield_now()` in a loop.
- Cover waiting behavior by measuring the thread's own CPU time
	(`CLOCK_THREAD_CPUTIME_ID`), not wall-clock time - wall clock cannot tell a
	sleeping thread from a spinning one. See
	`decoder_sleeps_instead_of_spinning_while_the_ring_is_full`.
- cpal handles ALSA `EPIPE` silently and never invokes the error callback, so
	underruns leave no trace in the log. Verify on hardware through the PCM
	status instead: `trigger_time` must stay constant and `hw_ptr` must rise
	monotonically (`resources/debos/debug-pi-audio.sh`).

## Development Process Guidelines
- Don't run the graphical application unless absolutely necessary. Prefer writing tests to answer your questions instead if possible
- Prefer `cargo check` as a first layer of validating your code
- Always run `cargo fmt` and then `cargo fmt -- --check` after Rust changes
- Run `cargo test` after you are done with each task to ensure that you haven't introduced any regressions

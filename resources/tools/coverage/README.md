# Code coverage

CI measures line coverage in the backend and frontend jobs. It does not set a threshold, so the report is there to read and never fails a build.

You can find the report in two places:
- The job overview on GitHub shows the summary: the total, each folder, and the files with the most uncovered lines.
- The artifacts `coverage-backend` and `coverage-frontend` hold the full `lcov.info`, kept for 30 days. Paths in it are relative to `src/backend` and `src/frontend`.

The frontend summary leaves out `lib/lib/`, because that is the gRPC code protoc generates, not ours.

## Running it locally

### Backend

Install the tools once:

```sh
rustup component add llvm-tools-preview
cargo install cargo-llvm-cov --locked
```

Then, from `src/backend`:

```sh
cargo llvm-cov --summary-only          # table in the terminal
cargo llvm-cov --html --open           # browsable report
cargo llvm-cov --lcov --output-path lcov.info
python3 ../../resources/tools/coverage/lcov_summary.py lcov.info --title Backend --root .
```

### Frontend

From `src/frontend`, using the Flutter of the emb workspace:

```sh
flutter test --coverage                # writes coverage/lcov.info
python3 ../../resources/tools/coverage/lcov_summary.py coverage/lcov.info --title Frontend --exclude lib/lib/
```

## Limits

- **Rust test code counts too.** The tests sit in the same files as the code they test, so the percentage comes out a little high.
- **Flutter only counts files that a test loads.** A file that no test touches is missing from the report entirely, rather than showing up as 0 %. On 2026-11-15 that applied only to interfaces, colours, text keys, the translations and `main.dart`.
- **Code that needs the device is not covered.** That means the sound card, ALSA, udev and the socket start, which are checked on the Pi instead (see `docs/08-crosscutting.md`).

# Speech input trials (ADR-024)

Tools used on 2026-10-10 to choose models and a wake word for speech input,
before any of it is built (docs/09, ADR-024). Speech input waits for a USB
microphone in the car; these are for repeating the measurements with it.

Not here, on purpose: the recordings (a real voice; they stay on the shared
drive, `mikrofon-test-2026-10-10/`) and the models (about 500 MB, download
below).

## Setup (WSL)

```bash
python3 -m venv ~/.venvs/speech
~/.venvs/speech/bin/pip install -r requirements.txt
```

sherpa-onnx 1.13.8 is the version in the `carnine-voice` package, whose
`libsherpa-onnx-c-api.so` already has the keyword spotter, the offline
recognizer and the VAD.

## Models

Each from `https://github.com/k2-fsa/sherpa-onnx/releases/download/`,
unpacked into a folder of its own named `<archive>.d`:

```bash
curl -sSLO https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/<archive>.tar.bz2
mkdir <archive>.d && tar xjf <archive>.tar.bz2 -C <archive>.d
```

| Use | Release / archive | Size |
|---|---|---|
| Command recognition, German (chosen) | `asr-models/sherpa-onnx-nemo-stt_de_fastconformer_hybrid_large_pc-int8` | 99 MB |
| Recognition, four languages (best texts, slower than real time on the Pi) | `asr-models/sherpa-onnx-nemo-canary-180m-flash-en-es-de-fr-int8` | 146 MB |
| Comparison (unusable for German) | `asr-models/sherpa-onnx-whisper-base` | 197 MB |
| Voice activity detection | `asr-models/silero_vad.onnx` (a plain file) | 0.6 MB |
| Wake word, English (chosen) | `kws-models/sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01` | 16 MB |

sherpa-onnx has keyword models for English and Chinese only (2026-10-10).

## Recording

16 kHz, mono, 16 bit, the microphone by ALSA card name:

```bash
arecord -l
arecord -D plughw:CARD=<name>,DEV=0 -f S16_LE -r 16000 -c 1 file.wav
```

Count how often the wake word is said; the tools find hits and false
triggers, not the truth.

## Tools

| Tool | What |
|---|---|
| `erkenne.py MODELS_DIR RECORDING_DIR RESULT.md [nemo-de,canary,whisper-base]` | recognizes every `RECORDING_DIR/stuecke/*.wav` with each model, one thread; RTF per model, text and time per piece |
| `codewort.py KWS_DIR NEMO_DIR silero_vad.onnx "Hey Navi" WAV… [--spelling "Hey Navy"]` | counts the wake word: keyword model (thresholds 0.25 and 0.15) and VAD + NeMo-de with `speech_tools.wake_word_pattern`; prints every segment |
| `kws_probe.py KWS_DIR` | checks the keyword spotter on the model's own test recordings; run it first when `codewort.py` finds nothing |
| `speech_tools.py` | reading WAVs, wake word to tokens (every token must be in the model: `▁K ID`, not `▁KID`, or sherpa-onnx spots nothing), the text pattern |

Run them as `python script.py`, not `python -I`: they import
`speech_tools` from their own folder. Tests (no models, no numpy needed):
`python3 -m unittest test_speech_tools.py`.

## Measuring on carnine-pc

The Pi has no `ensurepip`, so no venv; everything under `/tmp` and removed
afterwards:

```bash
pip download sherpa-onnx==1.13.8 numpy --platform manylinux2014_aarch64 \
  --platform manylinux_2_28_aarch64 --python-version 313 --only-binary=:all: -d pi-wheels
# copy wheels, these tools, the model folders and the recordings to /tmp/asr on the Pi, then there:
cd /tmp/asr && for w in *.whl; do python3 -m zipfile -e "$w" site/; done
PYTHONPATH=/tmp/asr/site nice -n 10 taskset -c 2 python3 -s erkenne.py models aud result.md nemo-de,canary
rm -rf /tmp/asr
```

Core 2, so core 3 stays with the turn announcements.

## Results of 2026-10-10

In ADR-024 ("Findings 2026-10-10"). In short: NeMo-de RTF 0.035 on the PC and
0.35 on the Pi 4 (a 2 s command in 0.6–0.7 s); "Hey Navi" with the English
keyword model, no false trigger in about 10 min of music and 2 min of talk,
about half of them found in loud music; "Hey Carnine" and "Hey Kit" dropped.
A German synthetic voice (Piper Thorsten) is no stand-in for a speaker: the
keyword model did not even spot "Hey Siri" in it.

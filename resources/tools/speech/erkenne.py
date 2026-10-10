#!/usr/bin/env python3
"""Runs speech recognizers over the pieces of a recording (ADR-024 trials).

  erkenne.py MODELS_DIR RECORDING_DIR RESULT.md [nemo-de,canary,whisper-base]

Every RECORDING_DIR/stuecke/*.wav (16 kHz mono) is recognized on its own by
each model; prints load time, audio length, compute time and RTF per model and
writes the text of every piece with its compute time to RESULT.md.
MODELS_DIR holds the unpacked model archives as <archive>.d (README.md).
One thread, as on the Pi (taskset -c 2 there, core 3 belongs to the
announcements).
"""
import glob
import os
import sys
import time

import sherpa_onnx

from speech_tools import SAMPLE_RATE, load_wav

NEMO = "sherpa-onnx-nemo-stt_de_fastconformer_hybrid_large_pc-int8"
CANARY = "sherpa-onnx-nemo-canary-180m-flash-en-es-de-fr-int8"
WHISPER = "sherpa-onnx-whisper-base"


def recognizers(models):
    def path(name, file):
        return os.path.join(models, f"{name}.d", name, file)

    return {
        "nemo-de": lambda: sherpa_onnx.OfflineRecognizer.from_nemo_ctc(
            model=path(NEMO, "model.int8.onnx"), tokens=path(NEMO, "tokens.txt"), num_threads=1),
        "canary": lambda: sherpa_onnx.OfflineRecognizer.from_nemo_canary(
            encoder=path(CANARY, "encoder.int8.onnx"), decoder=path(CANARY, "decoder.int8.onnx"),
            tokens=path(CANARY, "tokens.txt"), src_lang="de", tgt_lang="de", num_threads=1),
        "whisper-base": lambda: sherpa_onnx.OfflineRecognizer.from_whisper(
            encoder=path(WHISPER, "base-encoder.int8.onnx"), decoder=path(WHISPER, "base-decoder.int8.onnx"),
            tokens=path(WHISPER, "base-tokens.txt"), language="de", task="transcribe", num_threads=1),
    }


def main():
    models, recording, result = sys.argv[1:4]
    chosen = recognizers(models)
    if len(sys.argv) > 4:
        chosen = {k: v for k, v in chosen.items() if k in sys.argv[4].split(",")}
    files = sorted(glob.glob(os.path.join(recording, "stuecke", "*.wav")))
    texts = {}
    for name, make in chosen.items():
        start = time.time()
        recognizer = make()
        loaded = time.time() - start
        audio_s = compute_s = 0.0
        for file in files:
            samples = load_wav(file)
            stream = recognizer.create_stream()
            stream.accept_waveform(SAMPLE_RATE, samples)
            start = time.time()
            recognizer.decode_stream(stream)
            took = time.time() - start
            audio_s += len(samples) / SAMPLE_RATE
            compute_s += took
            texts.setdefault(os.path.basename(file), {})[name] = (stream.result.text.strip(), took)
        print(f"{name}: load {loaded:.1f} s, audio {audio_s:.0f} s, compute {compute_s:.1f} s, "
              f"RTF {compute_s / audio_s:.3f}", flush=True)
    with open(result, "w", encoding="utf-8") as out:
        for file, by_model in texts.items():
            out.write(f"## {file}\n")
            for name, (text, took) in by_model.items():
                out.write(f"- {name} ({took:.2f} s): {text}\n")


if __name__ == "__main__":
    main()

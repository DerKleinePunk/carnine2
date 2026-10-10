#!/usr/bin/env python3
"""Counts a wake word in recordings, two ways (ADR-024 trials).

  codewort.py KWS_DIR NEMO_DIR silero_vad.onnx WAKE_WORD WAV... [--spelling S]...

1. Keyword spotting with the English model in KWS_DIR, which listens all the
   time: hits with their time, at thresholds 0.25 and 0.15. Extra --spelling
   entries are spotted alongside (e.g. "HEY NAVY" for "Hey Navi").
2. Voice activity detection (silero) cutting speech segments, each read by
   NeMo-de (NEMO_DIR); a segment counts when its text starts with the wake
   word (speech_tools.wake_word_pattern). Every segment is printed, so a
   miscount shows.

A recording without the wake word gives the false triggers, one with it the
hits; how often it was said has to be counted while recording.
"""
import argparse
import tempfile
import time

import numpy as np
import sherpa_onnx

from speech_tools import (SAMPLE_RATE, check_keyword_tokens, keyword_pieces, load_wav,
                          model_tokens, wake_word_pattern)

KWS_STEM = "epoch-12-avg-2-chunk-16-left-64.int8.onnx"


def keywords_file(kws_dir, spellings):
    known = model_tokens(f"{kws_dir}/tokens.txt")
    lines = []
    for spelling in spellings:
        pieces = keyword_pieces(spelling, f"{kws_dir}/bpe.model")
        tag = spelling.lower().replace(" ", "-")
        lines.append(f"{check_keyword_tokens(spelling, pieces, known)} @{tag}\n")
    out = tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False, encoding="utf-8")
    out.writelines(lines)
    out.close()
    return out.name


def spot(kws_dir, keywords, samples, threshold):
    spotter = sherpa_onnx.KeywordSpotter(
        tokens=f"{kws_dir}/tokens.txt", encoder=f"{kws_dir}/encoder-{KWS_STEM}",
        decoder=f"{kws_dir}/decoder-{KWS_STEM}", joiner=f"{kws_dir}/joiner-{KWS_STEM}",
        keywords_file=keywords, num_threads=1, keywords_threshold=threshold, keywords_score=2.0)
    stream, hits, step = spotter.create_stream(), [], SAMPLE_RATE // 10
    # Fed in 0.1 s pieces as from a microphone, then one second of silence.
    padded = np.concatenate([samples, np.zeros(SAMPLE_RATE, dtype=np.float32)])
    for i in range(0, len(padded), step):
        stream.accept_waveform(SAMPLE_RATE, padded[i:i + step])
        while spotter.is_ready(stream):
            spotter.decode_stream(stream)
            found = spotter.get_result(stream)
            if found:
                hits.append((round(i / SAMPLE_RATE, 1), found))
                spotter.reset_stream(stream)
    return hits


def segments(vad_model, recognizer, samples):
    config = sherpa_onnx.VadModelConfig()
    config.silero_vad.model = vad_model
    config.silero_vad.min_silence_duration = 0.3
    config.sample_rate = SAMPLE_RATE
    vad = sherpa_onnx.VoiceActivityDetector(config, buffer_size_in_seconds=60)
    found, compute_s = [], 0.0

    def drain():
        nonlocal compute_s
        while not vad.empty():
            segment = vad.front
            stream = recognizer.create_stream()
            stream.accept_waveform(SAMPLE_RATE, np.array(segment.samples, dtype=np.float32))
            start = time.time()
            recognizer.decode_stream(stream)
            compute_s += time.time() - start
            found.append((round(segment.start / SAMPLE_RATE, 1), len(segment.samples) / SAMPLE_RATE,
                          stream.result.text.strip()))
            vad.pop()

    window = config.silero_vad.window_size
    for i in range(0, len(samples), window):
        vad.accept_waveform(samples[i:i + window])
        drain()
    vad.flush()
    drain()
    return found, compute_s


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("kws_dir")
    parser.add_argument("nemo_dir")
    parser.add_argument("vad_model")
    parser.add_argument("wake_word")
    parser.add_argument("wavs", nargs="+")
    parser.add_argument("--spelling", action="append", default=[])
    args = parser.parse_args()

    keywords = keywords_file(args.kws_dir, [args.wake_word, *args.spelling])
    pattern = wake_word_pattern(args.wake_word)
    recognizer = sherpa_onnx.OfflineRecognizer.from_nemo_ctc(
        model=f"{args.nemo_dir}/model.int8.onnx", tokens=f"{args.nemo_dir}/tokens.txt", num_threads=1)
    for wav in args.wavs:
        samples = load_wav(wav)
        print(f"\n### {wav.split('/')[-1]} ({len(samples) / SAMPLE_RATE:.0f} s)")
        for threshold in (0.25, 0.15):
            hits = spot(args.kws_dir, keywords, samples, threshold)
            print(f"keyword model, threshold {threshold}: {len(hits)} hit(s) {hits}")
        found, compute_s = segments(args.vad_model, recognizer, samples)
        speech_s = sum(length for _, length, _ in found)
        matched = [start for start, _, text in found if pattern.search(text)]
        print(f"VAD: {len(found)} segment(s), {speech_s:.0f} s taken for speech, "
              f"NeMo-de {compute_s:.1f} s; wake word in the text: {len(matched)} {matched}")
        for start, _, text in found:
            print(f"  {start:7.1f} s {'**' if pattern.search(text) else '  '} {text}")


if __name__ == "__main__":
    main()

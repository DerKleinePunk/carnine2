#!/usr/bin/env python3
"""Checks that keyword spotting works at all: the keyword model's own test
recordings must give "LIGHT UP", "LOVELY CHILD" and "FOREVER".

  kws_probe.py KWS_DIR

Worth running first when codewort.py finds nothing: on 2026-10-10 a German
synthetic voice gave no hits even for "Hey Siri", while this probe passed,
so the voice was the problem, not the setup.
"""
import sys

import numpy as np
import sherpa_onnx

from speech_tools import SAMPLE_RATE, load_wav

STEM = "epoch-12-avg-2-chunk-16-left-64.int8.onnx"
EXPECTED = {"0.wav": ["LIGHT UP"], "1.wav": ["LOVELY CHILD", "FOREVER"]}


def main():
    kws = sys.argv[1]
    spotter = sherpa_onnx.KeywordSpotter(
        tokens=f"{kws}/tokens.txt", encoder=f"{kws}/encoder-{STEM}", decoder=f"{kws}/decoder-{STEM}",
        joiner=f"{kws}/joiner-{STEM}", keywords_file=f"{kws}/test_wavs/test_keywords.txt", num_threads=1)
    failed = False
    for name, expected in EXPECTED.items():
        stream = spotter.create_stream()
        stream.accept_waveform(SAMPLE_RATE, load_wav(f"{kws}/test_wavs/{name}"))
        stream.accept_waveform(SAMPLE_RATE, np.zeros(SAMPLE_RATE, dtype=np.float32))
        stream.input_finished()
        hits = []
        while spotter.is_ready(stream):
            spotter.decode_stream(stream)
            found = spotter.get_result(stream)
            if found:
                hits.append(found)
                spotter.reset_stream(stream)
        ok = hits == expected
        failed |= not ok
        print(f"{name}: {hits} {'ok' if ok else f'expected {expected}'}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

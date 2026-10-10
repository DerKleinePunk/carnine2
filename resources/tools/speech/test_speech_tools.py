#!/usr/bin/env python3
"""Tests for speech_tools.py. Run: python3 -m unittest test_speech_tools.py

Bare Python: nothing here needs numpy, sherpa-onnx, sentencepiece or a model.
The texts are what NeMo-de wrote for the recordings of 2026-10-10.
"""
import tempfile
import unittest
import wave
from pathlib import Path

import speech_tools


class WakeWordPatternTest(unittest.TestCase):
    def setUp(self):
        self.pattern = speech_tools.wake_word_pattern("Hey Navi")

    def test_what_nemo_wrote_for_hey_navi_matches(self):
        for text in ("Herr Navi", "Herr Navi .", "Ray Naviy", "in Navi", "y Nav", "Hey Navi"):
            self.assertTrue(self.pattern.search(text), text)

    def test_talk_and_music_of_the_trials_does_not(self):
        for text in ("Das war Sie gesagtgt , links", "habe Hunger", "Heyna wie", "Hena wie", "",
                     "Ich glaube, das Navi sagt links", "Erzählen soll ja , die Kinderin gehts gut"):
            self.assertFalse(self.pattern.search(text), text)

    def test_uses_the_last_word(self):
        pattern = speech_tools.wake_word_pattern("Hallo Computer")
        self.assertIsNone(pattern.search("Hallo Kompjuter"))
        self.assertTrue(pattern.search("Hallo Computer"))


class KeywordTokensTest(unittest.TestCase):
    def test_known_pieces_are_joined(self):
        known = {"▁HE", "Y", "▁NA", "VI"}
        self.assertEqual(speech_tools.check_keyword_tokens("HEY NAVI", ["▁HE", "Y", "▁NA", "VI"], known),
                         "▁HE Y ▁NA VI")

    def test_an_unknown_piece_stops(self):
        # sherpa-onnx would only log it and then spot nothing at all.
        with self.assertRaisesRegex(SystemExit, "▁KID not in the model's tokens"):
            speech_tools.check_keyword_tokens("HEY KID", ["▁HE", "Y", "▁KID"], {"▁HE", "Y", "▁K", "ID"})

    def test_model_tokens_reads_the_first_column(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "tokens.txt"
            path.write_text("<blk> 0\n▁HE 1\nY 2\n\n", encoding="utf-8")
            self.assertEqual(speech_tools.model_tokens(path), {"<blk>", "▁HE", "Y"})


class LoadWavTest(unittest.TestCase):
    def write(self, rate, channels):
        tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
        tmp.close()
        with wave.open(tmp.name, "wb") as w:
            w.setnchannels(channels)
            w.setsampwidth(2)
            w.setframerate(rate)
            w.writeframes(b"\x00\x00" * channels * 10)
        self.addCleanup(Path(tmp.name).unlink)
        return tmp.name

    def test_wrong_rate_stops_with_the_arecord_line(self):
        with self.assertRaisesRegex(SystemExit, "48000 Hz.*arecord -f S16_LE -r 16000 -c 1"):
            speech_tools.load_wav(self.write(48000, 1))

    def test_stereo_stops(self):
        with self.assertRaisesRegex(SystemExit, "2 channel"):
            speech_tools.load_wav(self.write(16000, 2))

    def test_right_format_reads(self):
        try:
            import numpy  # noqa: F401
        except ImportError:
            self.skipTest("numpy not installed")
        samples = speech_tools.load_wav(self.write(16000, 1))
        self.assertEqual(len(samples), 10)


if __name__ == "__main__":
    unittest.main()

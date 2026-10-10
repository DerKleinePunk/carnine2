"""Shared helpers for the speech input trials (ADR-024): reading recordings,
turning a wake word into the keyword model's tokens, finding it in a text.

numpy, sherpa-onnx and sentencepiece are imported where they are used, so
the tests run on a bare Python (as in CI).
"""
import re
import wave
from pathlib import Path

SAMPLE_RATE = 16000


def load_wav(path):
    """The samples of a 16 kHz mono 16-bit WAV as float32 in -1..1."""
    with wave.open(str(path)) as w:
        shape = (w.getframerate(), w.getnchannels(), w.getsampwidth())
        if shape != (SAMPLE_RATE, 1, 2):
            raise SystemExit(f"{path}: {shape[0]} Hz, {shape[1]} channel(s), {8 * shape[2]} bit; "
                             "expected 16000 Hz mono 16 bit "
                             "(arecord -f S16_LE -r 16000 -c 1)")
        frames = w.readframes(w.getnframes())
    import numpy as np

    return np.frombuffer(frames, dtype=np.int16).astype(np.float32) / 32768


def model_tokens(tokens_txt):
    """The token set of a sherpa-onnx model (first column of tokens.txt)."""
    return {line.split()[0] for line in Path(tokens_txt).read_text(encoding="utf-8").splitlines()
            if line.strip()}


def check_keyword_tokens(keyword, pieces, known):
    """The pieces of a keyword, joined as a keywords file line wants them.

    Every piece must be a token of the model: sherpa-onnx otherwise only logs
    "Cannot find ID for token" and spots nothing at all (▁KID is not a token,
    ▁K ID is).
    """
    missing = [p for p in pieces if p not in known]
    if missing:
        raise SystemExit(f"keyword {keyword!r}: {' '.join(missing)} not in the model's tokens")
    return " ".join(pieces)


def keyword_pieces(keyword, bpe_model):
    """The keyword split by the keyword model's BPE (sentencepiece)."""
    import sentencepiece

    sp = sentencepiece.SentencePieceProcessor(model_file=str(bpe_model))
    return sp.encode(keyword.upper(), out_type=str)


def wake_word_pattern(wake_word):
    """A pattern for the wake word in a recognizer's text.

    NeMo-de writes "Hey Navi" as "Herr Navi", "Ray Naviy", "in Navi" or just
    "y Nav": the greeting is unreliable, the name mostly comes through. So the
    pattern looks for the start of the last word (three letters) at the start
    of a speech segment, with at most one word before it. A sentence that only
    mentions the word further on ("ich glaube, das Navi sagt links") does not
    match; "das Navi sagt links" on its own would. Crude on purpose: it is for
    counting trial recordings, not the product.
    """
    stem = re.escape(wake_word.split()[-1][:3])
    return re.compile(rf"^\W*(\w+\W+)?{stem}", re.IGNORECASE)

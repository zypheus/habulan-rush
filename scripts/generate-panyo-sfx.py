"""Generate original, license-safe Agawan ng Panyo UI cues as mono WAV files.

Upload the WAVs through the project owner's Roblox account, then enter the
approved asset IDs in Config.Panyo.Sounds. No runtime code reads local WAVs.
"""

from math import exp, pi, sin
from pathlib import Path
from struct import pack
import wave


SAMPLE_RATE = 22050
OUTPUT = Path(__file__).resolve().parents[1] / "assets" / "sfx" / "panyo"


def render(name: str, duration: float, notes: list[tuple[float, float, float, float]]) -> None:
    """Each note is (start, duration, frequency, amplitude)."""
    OUTPUT.mkdir(parents=True, exist_ok=True)
    samples = []
    for index in range(int(duration * SAMPLE_RATE)):
        time = index / SAMPLE_RATE
        value = 0.0
        for start, length, frequency, amplitude in notes:
            age = time - start
            if 0 <= age < length:
                attack = min(1.0, age / 0.015)
                release = min(1.0, (length - age) / 0.06)
                envelope = attack * release * exp(-2.4 * age / length)
                value += amplitude * envelope * (
                    sin(2 * pi * frequency * age)
                    + 0.18 * sin(2 * pi * frequency * 2 * age)
                )
        samples.append(pack("<h", round(max(-0.85, min(0.85, value)) * 32767)))
    with wave.open(str(OUTPUT / name), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(SAMPLE_RATE)
        audio.writeframes(b"".join(samples))


render("pickup.wav", 0.42, [(0, 0.22, 523.25, 0.27), (0.08, 0.22, 659.25, 0.24), (0.16, 0.23, 783.99, 0.23)])
render("steal.wav", 0.43, [(0, 0.18, 392.00, 0.22), (0.08, 0.22, 587.33, 0.25), (0.17, 0.25, 880.00, 0.24)])
render("drop.wav", 0.35, [(0, 0.18, 440.00, 0.20), (0.10, 0.23, 293.66, 0.23)])
render("reveal.wav", 0.65, [(0, 0.48, 659.25, 0.18), (0.12, 0.50, 987.77, 0.15)])
render("final.wav", 0.34, [(0, 0.13, 659.25, 0.22), (0.16, 0.15, 659.25, 0.22)])

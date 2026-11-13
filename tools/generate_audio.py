#!/usr/bin/env python3
"""Create SONAR's original PCM sound library, without downloaded samples.

Deterministic additive/noise synthesis. Run from any working directory.
Effects are mono for Godot's 3D emitter; score/ambience are seamless stereo.
"""
from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
TAU = math.tau
RNG = random.Random(0x534F4E4152)


def write(name: str, samples: list[float], channels: int = 1, loop: bool = False):
    peak = max(max(map(abs, samples), default=1.0), 1.0)
    packed = bytearray()
    for value in samples:
        # Soft saturation avoids hard clipping when transients overlap.
        packed.extend(struct.pack("<h", int(max(-1, min(1, value / peak)) * 30000)))
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as output:
        output.setnchannels(channels)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(packed)
    # WAV import loop settings are portable and remain visible in source control.
    # Godot itself supplies the remap/import path; a template is not safe to author.
    print(f"{name:20s} {len(samples) / RATE / channels:4.2f}s  {len(packed):7d} bytes")


def envelope(t: float, length: float, attack: float = .006) -> float:
    return min(1.0, t / attack) * max(0, 1.0 - t / length) ** 1.8


def resonant(length: float, base: float, harmonics: tuple[float, ...], decay: float = 5.0,
             noise: float = 0.0, bend: float = 0.0) -> list[float]:
    samples = []
    filtered = 0.0
    for i in range(int(RATE * length)):
        t = i / RATE
        filtered = filtered * .63 + RNG.uniform(-1, 1) * .37
        sound = sum(math.sin(TAU * base * ratio * (t + bend * t * t)) /
                    (j + 1) ** 1.3 * math.exp(-t * decay * (1 + j * .23))
                    for j, ratio in enumerate(harmonics))
        samples.append((sound * .52 + filtered * noise) * envelope(t, length))
    return samples


def footstep(material: str, variant: int) -> list[float]:
    length = .26 if material != "water" else .39
    output = []
    filtered = 0.0
    base = {"stone": 130, "metal": 420, "crystal": 760, "water": 85,
            "dust": 95, "organic": 62}[material] * (1 + variant * .08)
    for i in range(int(length * RATE)):
        t = i / RATE
        raw = RNG.uniform(-1, 1)
        filtered = filtered * .76 + raw * .24
        impact = math.sin(TAU * (base * t + 18 * t * math.exp(-t * 70))) * math.exp(-t * 28)
        grit = filtered * math.exp(-t * (14 if material in ("dust", "water") else 35))
        ring = math.sin(TAU * base * 2.71 * t) * math.exp(-t * 15)
        amount = {"stone": .14, "metal": .52, "crystal": .65, "water": .04,
                  "dust": .04, "organic": .07}[material]
        splash = math.sin(TAU * (380 * t - 650 * t * t)) * math.exp(-t * 11) if material == "water" else 0
        output.append((impact * .43 + grit * .5 + ring * amount + splash * .17) * envelope(t, length, .002))
    return output


def score_loop(length: float = 16.0, ambient: bool = False) -> list[float]:
    """All oscillators fit integer cycles; constant-power/noise loop has no seam."""
    count = int(length * RATE)
    seed_noise = [RNG.uniform(-1, 1) for _ in range(count)]
    smooth = 0.0
    bed = []
    for n in seed_noise:
        smooth = smooth * .993 + n * .007
        bed.append(smooth)
    # Circular crossfade removes low-pass startup discontinuity.
    tail = bed[-int(.2 * RATE):]
    for i, value in enumerate(tail):
        mix = i / len(tail)
        bed[i] = value * (1 - mix) + bed[i] * mix
    notes = [110.0, 130.8125, 164.8125, 220.0]  # rounded to exact loop periods below
    output = []
    for i in range(count):
        t = i / RATE
        base = .0
        for k, note in enumerate(notes):
            freq = round(note * length) / length
            amplitude = .017 if ambient else .040
            base += math.sin(TAU * freq * t + .18 * math.sin(TAU * (k + 1) * t / length)) * amplitude / (k + 1)
        breath = .7 + .3 * math.sin(TAU * t / length)
        air = bed[i] * (.7 if ambient else .2)
        sub = math.sin(TAU * 41.25 * t) * (.028 if ambient else .06) * breath
        # Sparse mineral notes, notes occur periodically, one at loop boundary too.
        pulse = 0.0
        if not ambient:
            for k in range(4):
                age = (t - k * length / 4) % length
                freq = round(notes[k] * 4 * length) / length
                pulse += math.sin(TAU * freq * age) * math.exp(-age * 2.0) * .07 * min(1, age / .012)
        left = (base + air + sub + pulse) * breath
        right = (base + bed[(i + 1409) % count] * (.7 if ambient else .2) + sub + pulse * .7) * breath
        output.extend((left, right))
    # Match endpoint values smoothly over 80ms. All tonal phases are already
    # periodic; this small noise correction removes a single-sample loop click.
    span = int(.08 * RATE)
    for channel in range(2):
        correction = output[channel] - output[(count - 1) * 2 + channel]
        for i in range(span):
            progress = i / (span - 1)
            smooth = progress * progress * (3 - 2 * progress)
            output[(count - span + i) * 2 + channel] += correction * smooth
    return output


def main():
    for material in ("stone", "metal", "crystal", "water", "dust", "organic"):
        for variation in range(3):
            write(f"step_{material}_{variation+1}", footstep(material, variation))
    write("rifle", resonant(.42, 94, (1, 2.77, 5.31, 9.2), 13, .85, -.25))
    write("pistol", resonant(.30, 158, (1, 2.49, 6.7), 18, .66, -.38))
    write("ping", resonant(1.25, 460, (1, 1.503, 2.005, 3.49), 2.6, .04, -.11))
    write("ping_charge", resonant(.17, 310, (1, 2.03), .5, .04, 5.4))
    write("contact", resonant(.36, 930, (1, 1.5, 2.0), 7.0, .03))
    write("ready", resonant(.22, 660, (1, 1.25, 1.5), 5.0, .02))
    write("reload", resonant(.58, 183, (1, 3.1, 5.6, 10.2), 11.0, .35, .2))
    write("impact", resonant(.30, 210, (1, 2.66, 4.24), 17.0, .60))
    write("hit", resonant(.18, 680, (1, 1.53, 2.09), 21.0, .3))
    write("land", resonant(.43, 59, (1, 2.71, 5.9), 13.0, .60))
    write("jump", resonant(.18, 137, (1, 3.3), 13.0, .14, .5))
    write("slide", resonant(.70, 78, (1, 2.8), 4.0, 1.0, -.08))
    write("gadget", resonant(.46, 420, (1, 2.7, 4.13), 5.4, .12))
    write("trap", resonant(.85, 225, (1, 1.493, 2.01, 3.79), 4.0, .22, -.12))
    write("jam", resonant(.90, 173, (1, 1.04, 1.517, 2.7), 1.3, .55, .04))
    write("extraction", resonant(1.30, 146.83, (1, 1.5, 2.0, 3.0), 1.7, .08, .018))
    write("extract_complete", resonant(1.55, 293.66, (1, 1.25, 1.5, 2.0), 1.6, .03, .015))
    write("death", resonant(.85, 73.41, (1, 1.5, 2.1), 3.0, .16, -.15))
    write("ui", resonant(.09, 880, (1, 2), 25.0, .02))
    write("ambience", score_loop(16.0, True), 2, True)
    write("menu_score", score_loop(16.0, False), 2, True)


if __name__ == "__main__":
    main()

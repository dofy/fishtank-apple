"""Three original, quiet aquarium loops. Standard library only; no sampled music.

16 bars per piece. Release tails wrap into the start so AVAudioPlayer can repeat
the PCM without a fade-to-silence gap. Does not regenerate existing audio assets.
"""
import array
import math
from pathlib import Path
import random
import sys
import wave

RATE = 22050
ROOT = Path(__file__).resolve().parents[1] / 'Sources/Resources/Audio'
TAU = math.tau


def note(buffer, beat, midi, duration, volume, voice, seconds):
    start = round(beat * seconds * RATE)
    count = round(duration * seconds * RATE)
    frequency = 440 * 2 ** ((midi - 69) / 12)
    for i in range(count):
        t = i / RATE
        x = TAU * frequency * t
        attack = min(1, t / .012)
        release = min(1, (count - i) / (RATE * .12))
        if voice == 'pluck':
            sample = math.sin(x) + .28 * math.sin(2*x) + .12 * math.sin(3*x)
            envelope = math.exp(-t * 3.8)
        elif voice == 'bell':
            sample = math.sin(x + .5 * math.sin(2*x) * math.exp(-t*5))
            envelope = math.exp(-t * 2.7)
        elif voice == 'bass':
            sample = math.sin(x) + .16 * math.sin(2*x)
            envelope = math.exp(-t * 2)
        else:  # Soft electric piano: a short tine over a warm fundamental.
            sample = math.sin(x) + .16*math.sin(2*x)*math.exp(-t*4) + .08*math.sin(3*x)
            envelope = math.exp(-t * 1.7)
        buffer[(start + i) % len(buffer)] += sample * envelope * attack * release * volume


def render(name, bpm, chords, melody, style):
    seconds = 60 / bpm
    buffer = [0.] * round(64 * seconds * RATE)
    for bar in range(16):
        chord = chords[bar % len(chords)]
        start = bar * 4
        if style == 'japanese':
            for offset, pitch in zip([0, 1, 2, 3], chord):
                note(buffer, start+offset, pitch, 2.4, .038, 'pluck', seconds)
            note(buffer, start, chord[0]-12, 3.5, .027, 'bass', seconds)
        elif style == 'taiwan':
            for pitch in chord:
                note(buffer, start, pitch, 3.7, .026, 'keys', seconds)
            for offset, pitch in [(0, chord[0]-12), (2, chord[0]-5)]:
                note(buffer, start+offset, pitch, 1.7, .035, 'bass', seconds)
            for offset, pitch in zip([1, 1.5, 3, 3.5], chord):
                note(buffer, start+offset, pitch+12, .8, .012, 'pluck', seconds)
        else:
            for offset in [.0, 2.65]:
                for pitch in chord[1:]:
                    note(buffer, start+offset, pitch, 1.25, .027, 'keys', seconds)
            for offset, pitch in enumerate([chord[0]-12, chord[0]-5, chord[0]-2, chord[0]-1]):
                note(buffer, start+offset, pitch, .85, .036, 'bass', seconds)
        for offset, pitch, duration in melody[bar % len(melody)]:
            # Second phrase answers the first with a gentler top voice.
            voice = 'keys' if style == 'jazz' else 'bell' if style == 'japanese' else 'pluck'
            swing = .16 if style == 'jazz' and offset % 1 == .5 else 0
            note(buffer, start+offset+swing, pitch, duration, .043 if bar < 8 else .036, voice, seconds)
    if style == 'jazz':
        rng = random.Random(731)
        last = 0.
        for beat in range(64):
            start = round((beat + (2/3 if beat % 2 else 0)) * seconds * RATE)
            for i in range(round(.085 * RATE)):
                noise = rng.uniform(-1, 1)
                # Quiet high-passed brush, with a smooth onset and decay.
                brush = (noise-last) * .5
                last = noise
                t = i/RATE
                env = min(1, t/.005) * math.exp(-t*65)
                buffer[(start+i) % len(buffer)] += brush*env*.012
    rms = math.sqrt(sum(x*x for x in buffer) / len(buffer))
    peak = max(abs(x) for x in buffer)
    gain = min(.026/rms, .24/peak)
    pcm = array.array('h', (round(x*gain*32767) for x in buffer))
    if sys.byteorder != 'little':
        pcm.byteswap()
    ROOT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(ROOT / ('music-' + name + '.wav')), 'wb') as output:
        output.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        output.writeframes(pcm.tobytes())
    print(f'{name}: {len(buffer)/RATE:.2f}s; RMS {rms*gain:.4f}; peak {peak*gain:.4f}')


if __name__ == '__main__':
    render('japanese', 88,
           [[50,57,62,65], [46,53,58,62], [48,55,60,64], [45,52,57,60],
            [43,50,57,62], [46,53,58,65], [48,55,60,64], [45,52,57,64]],
           [[(0,74,1.4),(2,77,.8),(3,81,.8)], [(0,77,1.8),(2.5,74,1.2)],
            [(0,72,1),(1.5,76,1),(3,79,.8)], [(0,76,2.5)],
            [(0,74,1),(1.5,69,1),(3,72,.8)], [(0,70,1.5),(2,74,1.4)],
            [(0,72,1),(1.5,76,1),(3,74,.8)], [(0,69,2.4),(3,72,.6)]], 'japanese')
    render('taiwan', 76,
           [[48,55,60,64], [45,52,57,60], [41,48,53,57], [43,50,55,59],
            [40,47,52,55], [45,52,57,60], [41,48,53,57], [43,50,55,62]],
           [[(0,72,1),(1.5,74,.8),(3,76,.8)], [(0,79,1.5),(2,76,1.5)],
            [(0,74,1),(1,72,1),(2.5,69,1)], [(0,67,2.8)],
            [(0,69,1),(1.5,72,1),(3,74,.8)], [(0,76,1.5),(2,79,1.5)],
            [(0,76,1),(1,74,1),(2.5,72,1)], [(0,74,1.3),(2,67,1.5)]], 'taiwan')
    render('jazz', 96,
           [[48,55,59,64,69], [45,55,60,64,71], [50,57,60,65,69], [43,53,59,64,69],
            [52,55,59,62,66], [45,55,61,64,70], [50,57,60,65,69], [43,53,59,64,68]],
           [[(0,76,.8),(1.5,74,.5),(2.5,71,1)], [(0,72,1.5),(2.5,76,.7)],
            [(.5,77,.6),(1.5,76,.5),(3,72,.8)], [(0,71,1),(2,69,1.5)],
            [(.5,74,.6),(1.5,78,.5),(3,76,.7)], [(0,73,1.5),(2.5,70,1)],
            [(0,69,.8),(1.5,72,.6),(2.5,76,.7)], [(0,71,1.3),(2.5,68,.9)]], 'jazz')

"""Render the web game's oscillator patterns to deterministic bundled PCM WAVs.
Input: /tmp/fishtank-extras-data.json exported from the original source.
Only the Python standard library is used. No external audio or PC FISH assets.
"""
import array, json, math, pathlib, wave
RATE = 22050
ROOT = pathlib.Path(__file__).resolve().parents[1] / 'Sources/Resources/Audio'
ROOT.mkdir(parents=True, exist_ok=True)

def tone(buffer, start, f0, f1, duration, peak, waveform, loop=False):
    phase = 0.0
    count = int(duration * RATE)
    attack = min(0.015, duration * 0.25)
    for i in range(count):
        t = i / RATE
        f = f0 * (max(40, f1) / f0) ** (t / duration)
        phase += f / RATE
        p = phase % 1
        if waveform == 'sine': sample = math.sin(2 * math.pi * p)
        elif waveform == 'triangle': sample = 1 - 4 * abs(p - 0.5)
        elif waveform == 'square': sample = 1 if p < 0.5 else -1
        else: sample = 2 * p - 1
        env = peak * t / attack if t < attack else peak * (0.0001 / max(peak, 0.0001)) ** ((t - attack) / max(0.001, duration - attack))
        j = int(start * RATE) + i
        if loop: j %= len(buffer)
        if j < len(buffer): buffer[j] += sample * env

def save(name, notes, length, loop=False):
    samples = [0.] * int(length * RATE)
    for note in notes: tone(samples, *note, loop=loop)
    pcm = array.array('h', (round(max(-0.98, min(0.98, x)) * 32767) for x in samples))
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE); f.writeframes(pcm.tobytes())

tracks = json.load(open('/tmp/fishtank-extras-data.json'))['tracks']
for name, pattern in tracks.items():
    step = pattern['stepMs'] / 1000
    master = 0.055 if pattern['wave'] == 'square' else 0.11
    notes = []
    freq = lambda midi: 440 * 2 ** ((midi - 69) / 12)
    for i, note in enumerate(pattern['melody']):
        if i % 8 == 0:
            for n in pattern['chords'][(i // 8) % len(pattern['chords'])]:
                notes.append((i * step, freq(n), freq(n), step * 7.2, master * 0.55, 'triangle' if pattern['wave'] == 'square' else 'sine'))
        if note is not None: notes.append((i * step, freq(note), freq(note), step * 1.6, master, pattern['wave']))
    save('music-' + name, notes, 32 * step, True)

p = 0.28
sounds = {
 'click': [(0,620,740,.045,p*.7,'triangle')],
 'select': [(0,520,780,.07,p*.85,'sine')],
 'place': [(0,380,580,.09,p*.85,'sine'),(.06,580,760,.09,p*.65,'sine')],
 'release': [(0,540,320,.14,p*.75,'sine')],
 'feed': [(0,880,620,.055,p*.6,'sine')],
 'eat': [(0,520,840,.06,p*.65,'triangle')],
 'scare': [(0,420,960,.09,p*.8,'sine')],
 'error': [(0,220,175,.11,p*.95,'sawtooth'),(.1,185,145,.14,p*.95,'sawtooth')],
 'zap': [(i*.04,f,f*.65,.045,p*.85,'sawtooth') for i,f in enumerate([980,320,1180,260,860])],
 'breed': [(i*.14,f,f*1.03,.16,p*.85,'sine') for i,f in enumerate([523.25,659.25,783.99,987.77,1046.5])],
 'merge': [(i*.11,330*1.12**i,330*1.12**i*1.08,.11,p*.85,'triangle') for i in range(8)]
}
for tier in range(6):
    base = 523.25 * (1 + tier * 0.05)
    sounds['reveal-' + str(tier)] = [(i*.08,base*r,base*r,.28,p,'triangle') for i,r in enumerate([1,1.25,1.5,2])]
for name, notes in sounds.items(): save(name, notes, max(n[0]+n[3] for n in notes) + .03)
print('Rendered', len(tracks), 'music loops and', len(sounds), 'effects.')

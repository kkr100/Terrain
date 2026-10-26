"""Cuts the looping engine sounds in sounds/engines/ out of real recordings.

You don't need this to play the game. It's here so you can see how the loops
were made, and make new ones from other recordings.

    pip install numpy scipy
    python3 tools/make_engine_loops.py <folder with the recordings>

The folder needs 4-Cylinder.mp3, 6-Cylinder.mp3 and V8-Engine.m4a (and ffmpeg
installed to read them).

How it works, for each car:
1. Follow the engine's note through the recording (its "firing frequency":
   how many times per second a cylinder fires), so we know the RPM at every
   moment.
2. For each loop, take a second or so of the recording and gently stretch it
   so the RPM stays exactly the same the whole time.
3. Cut it into tiny pieces, one per cylinder firing, and lay them back down
   one after another. The end of the loop fades into its start, so it
   loops without a click.
   Laying the pieces closer together (or further apart) than in the
   recording makes the engine fire faster (or slower) without changing its
   voice. Together with playing the sound a bit faster or slower, that's how
   we get RPMs the recording never reached, like the V8 near its redline.
"""
import os
import struct
import subprocess
import sys

import numpy as np
from scipy import signal

RATE = 44100
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "sounds", "engines")

# For each car: the recording, how many cylinders, how to turn the firing
# frequency into RPM, which note to follow, and the loops to make.
# A loop is (start second, end second, RPM the recording has there, RPM we
# want). None as the wanted RPM keeps the recording's RPM.
ENGINES = {
	"rally": {
		"file": "4-Cylinder.mp3", "cylinders": 4,
		"loops": [(0.9, 1.5, 1380, 900), (1.6, 2.4, 1800, None),
				(3.0, 3.9, 2400, None), (4.9, 5.9, 3100, None),
				(23.2, 24.6, 4300, None), (20.8, 21.9, 5550, None),
				(7.9, 8.55, 6100, None), (7.9, 8.55, 6100, 7500)],
	},
	"suv": {
		"file": "6-Cylinder.mp3", "cylinders": 6,
		"loops": [(0.35, 0.85, 2900, 900), (0.35, 0.85, 2900, 1700),
				(0.35, 0.85, 2900, None), (16.3, 17.1, 3700, None),
				(1.45, 2.05, 4400, None), (5.5, 6.4, 5200, None),
				(11.8, 12.9, 6350, None)],
	},
	"pickup": {
		"file": "V8-Engine.m4a", "cylinders": 8, "skip": 7.0,
		"loops": [(2.0, 6.0, 1110, 700), (2.0, 6.0, 1110, None),
				(27.5, 31.5, 1600, None), (33.9, 37.0, 1800, None),
				(33.9, 37.0, 1800, 2500), (33.9, 37.0, 1800, 3500),
				(33.9, 37.0, 1800, 4800)],
	},
}


def load(path: str, skip: float) -> np.ndarray:
	raw = subprocess.run(
		["ffmpeg", "-loglevel", "error", "-ss", str(skip), "-i", path,
		"-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"],
		check=True, capture_output=True).stdout
	x = np.frombuffer(raw, np.float32).astype(float)
	x = signal.sosfiltfilt(signal.butter(2, 25, "highpass", fs=RATE, output="sos"), x)
	return x / np.abs(x).max()


def track(x, start, end, fmin, fmax):
	"""Follows the firing frequency between fmin and fmax (10 ms steps)."""
	hop = 441
	a = max(0, int((start - 0.3) * RATE))
	freqs, times, z = signal.stft(x[a:int((end + 0.3) * RATE)], RATE,
		nperseg=4096, noverlap=4096 - hop, nfft=16384)
	times += a / RATE
	log_mag = np.log(np.abs(z) + 1e-6)
	grid = np.arange(fmin, fmax, 0.5)
	bins = np.arange(len(freqs))
	score = log_mag[np.round(np.interp(grid, freqs, bins)).astype(int)]
	# Find the smoothest strong path (Viterbi): big jumps cost extra.
	n = len(grid)
	total = score[:, 0].copy()
	back = np.zeros((n, len(times)), int)
	for j in range(1, len(times)):
		best = np.full(n, -1e9)
		arg = np.zeros(n, int)
		for step in range(-120, 121):
			cand = np.roll(total, step) - 0.08 * abs(step)
			if step > 0:
				cand[:step] = -1e9
			elif step < 0:
				cand[step:] = -1e9
			better = cand > best
			best[better] = cand[better]
			arg[better] = (np.arange(n) - step)[better]
		total = best + score[:, j]
		back[:, j] = arg
	path = np.zeros(len(times), int)
	path[-1] = np.argmax(total)
	for j in range(len(times) - 1, 0, -1):
		path[j - 1] = back[path[j], j]
	return times, signal.savgol_filter(grid[path], 11, 2)


def flatten_pitch(x, times, freq, start, end):
	"""Stretches x[start:end] so the firing frequency stays constant.
	Returns the stretched sound and that frequency."""
	pad = 0.1
	t = np.arange(int((start - pad) * RATE), int((end + pad) * RATE)) / RATE
	f = np.interp(t, times, freq)
	phase = np.cumsum(f) / RATE  # counts cylinder firings
	f_const = float(np.median(np.interp(np.arange(start, end, 0.01), times, freq)))
	out_phase = np.arange(phase[0], phase[-1], f_const / RATE)
	out_time = np.interp(out_phase, phase, t)
	return np.interp(out_time, np.arange(len(x)) / RATE, x), f_const


def make_loop(sound, f_src, f_out, cylinders, seconds=1.2):
	"""Pitch-synchronous overlap-add: one piece of sound per firing."""
	period = RATE / f_src
	# Put each piece's centre on a firing (the loudest point of the period).
	env = np.abs(signal.hilbert(signal.sosfilt(
		signal.butter(2, [30, 2000], "bandpass", fs=RATE, output="sos"), sound)))
	phase = (np.arange(len(env)) % period).astype(int)
	fold = np.bincount(phase, env)[:int(period)]
	first = int(np.argmax(fold)) + int(period) + 2
	marks = np.arange(first, len(sound) - period - 1, period)
	marks = marks[:len(marks) // cylinders * cylinders]  # whole engine cycles
	width = int(round(period))
	window = np.hanning(2 * width + 1)

	out_period = RATE / f_out
	count = max(cylinders, int(round(seconds * f_out / cylinders)) * cylinders)
	length = int(round(count * out_period))
	# Make a bit more than one loop, then fade that extra bit into the start.
	extra = int(round(0.2 * f_out))
	pad = width + int(out_period) + 1  # room for the piece before the start
	out = np.zeros(int((count + extra + 2) * out_period) + 2 * pad)
	wsum = np.zeros(len(out))
	for j in range(-1, count + extra + 1):
		# Walk through the pieces forwards, then backwards, and so on, so
		# neighbouring pieces always came from neighbouring firings.
		i = j % (2 * len(marks) - 2)
		if i >= len(marks):
			i = 2 * len(marks) - 2 - i
		k = int(round(marks[i]))
		at = pad + int(round(j * out_period)) - width
		out[at:at + 2 * width + 1] += sound[k - width:k + width + 1] * window
		wsum[at:at + 2 * width + 1] += window
	out = (out / np.maximum(wsum, 1.0))[pad:]
	fade_len = int(round(extra * out_period))
	fade = np.sin(np.linspace(0, np.pi / 2, fade_len)) ** 2
	loop = out[:length].copy()
	loop[:fade_len] = loop[:fade_len] * fade + out[length:length + fade_len] * (1 - fade)
	return loop


def change_rpm(sound, f_src, f_out, cylinders):
	"""Makes a loop at f_out. Big changes are done half by moving the pieces
	(make_loop) and half by simply playing faster or slower (resampling).
	Moving the pieces alone keeps the engine's voice exactly the same, which
	sounds odd for big jumps: a real engine sounds brighter when it revs."""
	ratio = f_out / f_src
	if abs(ratio - 1.0) < 0.01:
		return make_loop(sound, f_src, f_out, cylinders)
	f_mid = f_src * np.sqrt(ratio)
	loop = make_loop(sound, f_src, f_mid, cylinders, 1.2 * f_out / f_mid)
	# signal.resample treats the sound as repeating forever, so the result
	# still loops perfectly.
	return signal.resample(loop, int(round(len(loop) * f_mid / f_out)))


def write_wav(path, data):
	"""16-bit mono WAV with a "smpl" chunk, so Godot knows it loops.

	Godot looks at a few samples on either side of the one it's playing (to
	play it smoothly at other speeds), even at the loop's ends. So we put a
	few extra samples before and after the loop: the end of the loop before
	it, and the start after it."""
	pad = 8
	padded = np.concatenate([data[-pad:], data, data[:pad]])
	pcm = np.clip(padded * 32767, -32768, 32767).astype("<i2").tobytes()
	fmt = struct.pack("<HHIIHH", 1, 1, RATE, RATE * 2, 2, 16)
	smpl = struct.pack("<9I", 0, 0, int(1e9 / RATE), 60, 0, 0, 0, 1, 0)
	smpl += struct.pack("<6I", 0, 0, pad, pad + len(data), 0, 0)
	chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt
	chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
	chunks += b"data" + struct.pack("<I", len(pcm)) + pcm
	with open(path, "wb") as f:
		f.write(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)


def main(folder):
	os.makedirs(OUT_DIR, exist_ok=True)
	for car, info in ENGINES.items():
		x = load(os.path.join(folder, info["file"]), info.get("skip", 0.0))
		cyl = info["cylinders"]
		for start, end, guess_rpm, rpm in info["loops"]:
			guess_hz = guess_rpm * cyl / 120.0
			times, freq = track(x, start, end, guess_hz * 0.8, guess_hz * 1.25)
			sound, f_src = flatten_pitch(x, times, freq, start, end)
			src_rpm = f_src * 120.0 / cyl
			rpm = rpm or int(round(src_rpm / 10.0) * 10)
			loop = change_rpm(sound, f_src, rpm * cyl / 120.0, cyl)
			loop *= 10 ** (-18 / 20) / np.sqrt(np.mean(loop ** 2))  # same loudness
			loop *= min(1.0, 0.98 / np.abs(loop).max())
			name = f"{car}_{rpm}.wav"
			write_wav(os.path.join(OUT_DIR, name), loop)
			print(f"{name}: {len(loop) / RATE:.2f} s from {start}-{end} s at {src_rpm:.0f} rpm")


if __name__ == "__main__":
	main(sys.argv[1])

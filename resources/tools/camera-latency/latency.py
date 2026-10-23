"""Shared analysis for latency_panel.py and latency_led.py.

Both tools switch a trigger (panel black/white, LED off/on) at irregular
intervals and record one brightness value per camera frame. A switch counts
as seen with the first frame after it whose value crosses the threshold in
the new direction. Pure functions only, no numpy, no devices.
"""
import statistics


def threshold(values):
    """(low, high, threshold) of the frame values.

    low/high are the 10 % and 90 % points, so a few frames in transition or
    with noise do not move them; the threshold lies halfway between.
    """
    if not values:
        raise ValueError('no frames')
    levels = sorted(values)
    lo, hi = levels[len(levels) // 10], levels[-len(levels) // 10]
    return lo, hi, (lo + hi) / 2


def latencies(toggles, frames, thr, tail=2.0):
    """Latency in ms for each switch that shows up in the frames.

    toggles: [(time_s, on)], frames: [(time_s, value)], both in time order.
    A frame only counts before the next switch (or `tail` s after the last).
    """
    lat = []
    for i, (t, on) in enumerate(toggles):
        nxt = toggles[i + 1][0] if i + 1 < len(toggles) else t + tail
        hit = next((ft for ft, v in frames
                    if t < ft < nxt and (v > thr if on else v < thr)), None)
        if hit is not None:
            lat.append((hit - t) * 1000)
    return lat


def spread(lat):
    """(median, 10 %, 90 %) in ms."""
    med = statistics.median(lat)
    if len(lat) < 2:
        return med, med, med
    q = statistics.quantiles(lat, n=10)
    return med, q[0], q[8]


def frame_rate(frames):
    """Frames per second from the median gap between frames."""
    gaps = [b[0] - a[0] for a, b in zip(frames, frames[1:])]
    gap = statistics.median(gaps) if gaps else 0
    return 1 / gap if gap > 0 else 0.0


def summary(label, frames, toggles, lat, lo, hi, levels=('dark', 'bright')):
    """Two lines for the console and the .txt file."""
    med, p10, p90 = spread(lat)
    return (
        f'{label}: {len(frames)} frames, {frame_rate(frames):.1f} frames/s, '
        f'{levels[0]} {lo:.0f} {levels[1]} {hi:.0f}\n'
        f'latency over {len(lat)} of {len(toggles)} switches: '
        f'median {med:.0f} ms, 10 % {p10:.0f} ms, 90 % {p90:.0f} ms, '
        f'min {min(lat):.0f}, max {max(lat):.0f}')


def raw_csv(frames, toggles):
    """Every frame and every switch, times in ms from the first switch."""
    t0 = toggles[0][0] if toggles else (frames[0][0] if frames else 0)
    return ('kind,t_ms,value\n'
            + ''.join(f'frame,{(t - t0) * 1000:.1f},{v:.1f}\n' for t, v in frames)
            + ''.join(f'switch,{(t - t0) * 1000:.1f},{int(on)}\n'
                      for t, on in toggles))


def latency_csv(lat):
    return 'latency_ms\n' + ''.join(f'{v:.1f}\n' for v in lat)


def evaluate(label, frames, toggles, levels=('dark', 'bright')):
    """(summary, latencies); SystemExit if no switch was seen."""
    lo, hi, thr = threshold([v for _, v in frames])
    lat = latencies(toggles, frames, thr)
    if not lat:
        raise SystemExit(f'no switch seen (values {lo:.0f}..{hi:.0f}) - '
                         'does the camera see the trigger?')
    return summary(label, frames, toggles, lat, lo, hi, levels), lat


def write_results(prefix, text, frames, toggles, lat):
    """<prefix>.txt (summary), <prefix>.csv (latencies), <prefix>-raw.csv."""
    with open(prefix + '-raw.csv', 'w') as f:
        f.write(raw_csv(frames, toggles))
    with open(prefix + '.txt', 'w') as f:
        f.write(text + '\n')
    with open(prefix + '.csv', 'w') as f:
        f.write(latency_csv(lat))

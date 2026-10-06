#!/usr/bin/env python3
"""A GPS mouse for the demo video that drives the route typed in the demo.

With navigation.position_source = "serial" the backend reads NMEA from
serial_device, a named pipe works too. Unlike the replay source, the map then
loads no route of its own, so the one typed on camera is the only one.

  demo_gps.py plan START_LAT START_LON DEST_LAT DEST_LON TRACK.json
                [--via LAT,LON]... [--valhalla URL]
      Asks Valhalla for the route the way the backend does (two locations,
      costing auto) and saves its shape and the speed of each stretch.
      Each --via is a point the drive passes through on the way, in order,
      without stopping. A drive with a detour leaves the route the map
      shows and so tests the reroute.
  demo_gps.py feed TRACK.json PIPE [--factor N] [--hz N]
      Writes GGA + RMC into PIPE: standing at the start until SIGUSR1, then
      the drive, then standing at the destination. --factor N covers N seconds
      of the drive per second of video; the displayed speed stays the real one.

demo.sh runs feed as the systemd unit carnine-demo-gps and sends SIGUSR1 with
systemctl kill. Do not signal it with pkill -f over SSH: the pattern is also in
the SSH command line, and SIGUSR1 ends that shell.
"""
import argparse
import datetime
import json
import math
import signal
import time
import urllib.request

EARTH_RADIUS_M = 6371008.8
# 50 km/h for a stretch that Valhalla gives no time for.
FALLBACK_SPEED_MS = 13.9


def decode_polyline6(shape):
    points, i, lat, lon = [], 0, 0, 0
    while i < len(shape):
        for which in (0, 1):
            result, shift = 0, 0
            while True:
                b = ord(shape[i]) - 63
                i += 1
                result |= (b & 0x1F) << shift
                shift += 5
                if b < 0x20:
                    break
            delta = ~(result >> 1) if result & 1 else result >> 1
            if which == 0:
                lat += delta
            else:
                lon += delta
        points.append((lat / 1e6, lon / 1e6))
    return points


def distance(a, b):
    la1, lo1, la2, lo2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 2 * EARTH_RADIUS_M * math.asin(math.sqrt(h))


def bearing(a, b):
    la1, lo1, la2, lo2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    y = math.sin(lo2 - lo1) * math.cos(la2)
    x = math.cos(la1) * math.sin(la2) - math.sin(la1) * math.cos(la2) * math.cos(lo2 - lo1)
    return (math.degrees(math.atan2(y, x)) + 360) % 360


def via_point(text):
    try:
        lat, lon = (float(part) for part in text.split(","))
    except ValueError:
        raise argparse.ArgumentTypeError(f"expected LAT,LON, got {text!r}")
    return lat, lon


def route_body(args):
    # A through location is passed on the way, the route does not stop there.
    vias = [{"lat": lat, "lon": lon, "type": "through"} for lat, lon in args.via]
    return {
        "locations": [{"lat": args.start_lat, "lon": args.start_lon}, *vias,
                      {"lat": args.dest_lat, "lon": args.dest_lon}],
        "costing": "auto",
        "directions_options": {"units": "kilometers"},
    }


def plan(args):
    body = json.dumps(route_body(args)).encode()
    request = urllib.request.Request(args.valhalla.rstrip("/") + "/route", body,
                                     {"Content-Type": "application/json"})
    trip = json.load(urllib.request.urlopen(request, timeout=60))["trip"]
    # speeds[i] is the speed from points[i] to points[i + 1], in m/s.
    points, speeds = [], []
    for leg in trip["legs"]:
        shape = decode_polyline6(leg["shape"])
        leg_speeds = [None] * (len(shape) - 1)
        for maneuver in leg["maneuvers"]:
            begin, end = maneuver["begin_shape_index"], maneuver["end_shape_index"]
            if end > begin and maneuver.get("time", 0) > 0:
                speed = maneuver["length"] * 1000 / maneuver["time"]
                for k in range(begin, end):
                    leg_speeds[k] = speed
        leg_speeds = [s or FALLBACK_SPEED_MS for s in leg_speeds]
        if points:
            # A leg starts where the previous one ended.
            shape = shape[1:]
        points += shape
        speeds += leg_speeds
    summary = trip["summary"]
    with open(args.track, "w") as out:
        json.dump({"points": points, "speeds": speeds,
                   "length_km": summary["length"], "time_s": summary["time"]}, out)
    print(f"{args.track}: {len(points)} points, {summary['length']:.1f} km, "
          f"{summary['time'] / 60:.0f} min")


def drive(track, factor, hz):
    """Yields (lat, lon, speed m/s, course) once per 1/hz seconds of video."""
    points, speeds = track["points"], track["speeds"]
    step_s = factor / hz
    # Stretch i, and how far into it the car is, in m.
    i, into = 0, 0.0
    while i < len(points) - 1:
        length = distance(points[i], points[i + 1])
        f = into / length if length else 1
        yield (points[i][0] + (points[i + 1][0] - points[i][0]) * f,
               points[i][1] + (points[i + 1][1] - points[i][1]) * f,
               speeds[i], bearing(points[i], points[i + 1]))
        left = speeds[i] * step_s
        while i < len(points) - 1 and left > 0:
            length = distance(points[i], points[i + 1])
            if into + left < length:
                into += left
                left = 0
            else:
                left -= length - into
                into = 0.0
                i += 1


def sentence(body):
    checksum = 0
    for ch in body:
        checksum ^= ord(ch)
    return f"${body}*{checksum:02X}\r\n"


def fix(lat, lon, speed, course):
    def coordinate(value, degree_digits, hemispheres):
        hemisphere = hemispheres[0] if value >= 0 else hemispheres[1]
        value = abs(value)
        degrees = int(value)
        return f"{degrees:0{degree_digits}d}{(value - degrees) * 60:07.4f}", hemisphere

    now = datetime.datetime.now(datetime.timezone.utc)
    la, la_h = coordinate(lat, 2, "NS")
    lo, lo_h = coordinate(lon, 3, "EW")
    hms = now.strftime("%H%M%S") + f".{now.microsecond // 10000:02d}"
    knots = speed / 0.514444
    heading = f"{course:.1f}" if speed > 0.5 else ""
    return (sentence(f"GPGGA,{hms},{la},{la_h},{lo},{lo_h},1,09,0.9,150.0,M,48.0,M,,")
            + sentence(f"GPRMC,{hms},A,{la},{la_h},{lo},{lo_h},{knots:.1f},{heading},"
                       f"{now.strftime('%d%m%y')},,,A"))


def feed(args):
    with open(args.track) as f:
        track = json.load(f)
    go = {"now": False}
    signal.signal(signal.SIGUSR1, lambda *_: go.update(now=True))
    start, dest = track["points"][0], track["points"][-1]
    period = 1 / args.hz
    while True:
        # Opening blocks until the backend reads the pipe; after a backend
        # restart it is opened again.
        try:
            with open(args.pipe, "w") as out:
                print("backend reading, standing at the start (SIGUSR1 to drive)", flush=True)
                while not go["now"]:
                    out.write(fix(start[0], start[1], 0, 0))
                    out.flush()
                    time.sleep(1)
                print("driving", flush=True)
                due = time.monotonic()
                for lat, lon, speed, course in drive(track, args.factor, args.hz):
                    out.write(fix(lat, lon, speed, course))
                    out.flush()
                    due += period
                    time.sleep(max(0, due - time.monotonic()))
                print("at the destination", flush=True)
                while True:
                    out.write(fix(dest[0], dest[1], 0, 0))
                    out.flush()
                    time.sleep(1)
        except BrokenPipeError:
            print("backend closed the pipe, waiting for it again", flush=True)
            time.sleep(1)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    p = commands.add_parser("plan")
    for name in ("start_lat", "start_lon", "dest_lat", "dest_lon"):
        p.add_argument(name, type=float)
    p.add_argument("track")
    p.add_argument("--via", type=via_point, action="append", default=[],
                   metavar="LAT,LON")
    p.add_argument("--valhalla", default="http://127.0.0.1:8002")
    f = commands.add_parser("feed")
    f.add_argument("track")
    f.add_argument("pipe")
    f.add_argument("--factor", type=float, default=1.0)
    f.add_argument("--hz", type=float, default=1.0)
    args = parser.parse_args(argv)
    {"plan": plan, "feed": feed}[args.command](args)


if __name__ == "__main__":
    main()

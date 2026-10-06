#!/usr/bin/env python3
"""Tests for demo_gps.py plan. Run: python3 -m unittest test_demo_gps.py"""
import contextlib
import http.server
import io
import json
import os
import tempfile
import threading
import unittest

import demo_gps


def encode_polyline6(points):
    out, last = [], (0, 0)
    for point in points:
        scaled = (round(point[0] * 1e6), round(point[1] * 1e6))
        for value in (scaled[0] - last[0], scaled[1] - last[1]):
            value = ~(value << 1) if value < 0 else value << 1
            while value >= 0x20:
                out.append(chr((0x20 | (value & 0x1F)) + 63))
                value >>= 5
            out.append(chr(value + 63))
        last = scaled
    return "".join(out)


def leg(points, length_km, time_s):
    return {"shape": encode_polyline6(points),
            "maneuvers": [{"begin_shape_index": 0, "end_shape_index": len(points) - 1,
                           "length": length_km, "time": time_s}]}


class FakeValhalla:
    """Remembers the request body and answers with the given trip."""

    def __init__(self, trip):
        bodies = self.bodies = []

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_POST(self):
                bodies.append(json.loads(self.rfile.read(int(self.headers["Content-Length"]))))
                answer = json.dumps({"trip": trip}).encode()
                self.send_response(200)
                self.send_header("Content-Length", str(len(answer)))
                self.end_headers()
                self.wfile.write(answer)

            def log_message(self, *args):
                pass

        self.server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.url = f"http://127.0.0.1:{self.server.server_port}"

    def close(self):
        self.server.shutdown()
        self.server.server_close()


class PlanTest(unittest.TestCase):
    START, VIA, DEST = (50.75, 9.27), (50.70, 9.30), (50.76, 9.28)

    def plan(self, trip, *extra):
        valhalla = FakeValhalla(trip)
        self.addCleanup(valhalla.close)
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        track = os.path.join(directory.name, "track.json")
        with contextlib.redirect_stdout(io.StringIO()):
            demo_gps.main(["plan", *map(str, self.START + self.DEST), track,
                           "--valhalla", valhalla.url, *extra])
        with open(track) as saved:
            return valhalla.bodies, json.load(saved)

    def test_without_via_the_request_has_start_and_destination_only(self):
        trip = {"legs": [leg([self.START, self.DEST], 1.3, 90)],
                "summary": {"length": 1.3, "time": 90}}
        bodies, track = self.plan(trip)

        self.assertEqual(len(bodies), 1)
        self.assertEqual(bodies[0]["locations"],
                         [{"lat": 50.75, "lon": 9.27}, {"lat": 50.76, "lon": 9.28}])
        self.assertEqual(track["points"], [list(self.START), list(self.DEST)])

    def test_vias_are_passed_through_in_order_and_the_legs_join(self):
        second_via = (50.72, 9.25)
        trip = {"legs": [leg([self.START, self.VIA], 6.0, 600),
                         leg([self.VIA, second_via], 3.0, 200),
                         leg([second_via, self.DEST], 4.5, 300)],
                "summary": {"length": 13.5, "time": 1100}}
        bodies, track = self.plan(trip, "--via", "50.70,9.30", "--via", "50.72,9.25")

        self.assertEqual(bodies[0]["locations"], [
            {"lat": 50.75, "lon": 9.27},
            {"lat": 50.70, "lon": 9.30, "type": "through"},
            {"lat": 50.72, "lon": 9.25, "type": "through"},
            {"lat": 50.76, "lon": 9.28},
        ])
        # The shared point between two legs appears once.
        self.assertEqual(track["points"], [list(self.START), list(self.VIA),
                                           list(second_via), list(self.DEST)])
        self.assertEqual(len(track["speeds"]), len(track["points"]) - 1)
        self.assertAlmostEqual(track["speeds"][0], 10.0)
        self.assertAlmostEqual(track["speeds"][1], 15.0)
        self.assertAlmostEqual(track["speeds"][2], 15.0)
        self.assertEqual(track["length_km"], 13.5)

    def test_a_via_that_is_not_lat_lon_is_refused(self):
        for text in ("50.7", "50.7,9.3,1", "north,9.3"):
            with self.subTest(text=text), self.assertRaises(SystemExit), \
                    contextlib.redirect_stderr(io.StringIO()):
                demo_gps.main(["plan", "50", "9", "51", "9", "t.json", "--via", text])


if __name__ == "__main__":
    unittest.main()

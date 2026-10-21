import io
import json
import unittest
from contextlib import redirect_stdout
from unittest import mock

import carmcp


def node(id, label, role='button', x=0, y=0, w=10, h=10, actions=()):
    return {'id': id, 'label': label, 'role': role,
            'rect': {'x': x, 'y': y, 'w': w, 'h': h}, 'actions': list(actions)}


SCREEN = [
    node(1, 'Optionen', x=0, y=400, w=90, h=60),
    node(2, 'Optionen System\nVersion 0.19.1', role='text', x=100),
    node(3, 'Suche', role='textField', x=300, y=60, w=400, h=40),
    node(4, None, role='group'),
]


class FakeServer:
    """Stands in for call(): answers ui_snapshot, records every tool call."""

    def __init__(self, screen):
        self.screen, self.calls = screen, []

    def __call__(self, method, params):
        self.calls.append((method, params))
        if method == 'tools/call' and params['name'] == 'ui_snapshot':
            text = json.dumps({'views': [{'result': {'nodes': self.screen}}]})
        else:
            text = 'ok'
        return {'result': {'content': [{'type': 'text', 'text': text}]}}

    def tools(self):
        return [(p['name'], p['arguments']) for m, p in self.calls
                if m == 'tools/call' and p['name'] != 'ui_snapshot']


class PayloadTest(unittest.TestCase):
    def test_plain_json(self):
        self.assertEqual(carmcp.payload('{"id": 1}'), {'id': 1})

    def test_server_sent_events_take_the_last_data_line(self):
        body = 'event: message\ndata: {"id": 1}\n\ndata: {"id": 2}\n'
        self.assertEqual(carmcp.payload(body), {'id': 2})


class MatchTest(unittest.TestCase):
    def test_exact_before_prefix_before_substring(self):
        ns = [node(1, 'Optionen System'), node(2, 'Optionen'),
              node(3, 'Alle Optionen')]
        self.assertEqual(carmcp.match(ns, 'Optionen')['id'], 2)
        self.assertEqual(carmcp.match(ns, 'Optionen S')['id'], 1)
        self.assertEqual(carmcp.match(ns, 'Alle')['id'], 3)

    def test_line_breaks_read_as_bars(self):
        self.assertEqual(carmcp.match(SCREEN, 'System | Version')['id'], 2)

    def test_no_match_and_nodes_without_label(self):
        self.assertIsNone(carmcp.match(SCREEN, 'Medien'))


class CenterTest(unittest.TestCase):
    def test_both_rect_spellings(self):
        self.assertEqual(carmcp.center(node(1, 'a', x=10, y=20, w=30, h=40)),
                         (25, 40))
        n = {'rect': {'left': 10, 'top': 20, 'width': 30, 'height': 40}}
        self.assertEqual(carmcp.center(n), (25, 40))


class KeyboardTest(unittest.TestCase):
    def test_keys_by_last_label_line_and_the_space_bar(self):
        ns = [node(1, 'A\nA'), node(2, 'a\na'), node(3, 'Leerzeichen'),
              node(4, 'X', role='text'), node(5, 'OK')]
        keys = carmcp.keyboard(ns)
        self.assertEqual(sorted(keys), [' ', 'a'])
        self.assertEqual(keys['a']['id'], 1)  # the first button wins
        self.assertEqual(keys[' ']['id'], 3)


class MainTest(unittest.TestCase):
    def run_main(self, screen, *argv):
        fake = FakeServer(screen)
        with mock.patch.object(carmcp, 'call', fake), \
                mock.patch.object(carmcp.time, 'sleep'), \
                redirect_stdout(io.StringIO()) as out:
            carmcp.main(list(argv))
        self.assertEqual(fake.calls[0][0], 'initialize')
        return fake, out.getvalue()

    def test_tap_hits_the_middle_of_the_node(self):
        fake, _ = self.run_main(SCREEN, 'tap', 'Optionen')
        self.assertEqual(fake.tools(), [('ui_tap_at', {'x': 45, 'y': 430})])

    def test_tapxy_and_long(self):
        fake, _ = self.run_main(SCREEN, 'tapxy', '46', '466')
        self.assertEqual(fake.tools(), [('ui_tap_at', {'x': 46.0, 'y': 466.0})])
        fake, _ = self.run_main(SCREEN, 'long', 'Suche')
        self.assertEqual(fake.tools(), [('ui_long_press', {'node_id': 3})])

    def test_type_taps_one_key_per_character(self):
        keys = [node(10, 'H\nH', x=0), node(11, 'I\nI', x=20),
                node(12, 'Leerzeichen', x=40, w=100)]
        fake, _ = self.run_main(keys, 'type', 'Hi h')
        self.assertEqual([a['x'] for _, a in fake.tools()], [5, 25, 90, 5])

    def test_a_missing_key_or_label_ends_with_a_message(self):
        with self.assertRaises(SystemExit) as e:
            self.run_main(SCREEN, 'type', 'x')
        self.assertIn("'x'", str(e.exception))
        with self.assertRaises(SystemExit) as e:
            self.run_main(SCREEN, 'tap', 'Medien')
        self.assertIn('Medien', str(e.exception))

    def test_nodes_filters_by_label_or_role(self):
        _, out = self.run_main(SCREEN, 'nodes', 'textField')
        self.assertEqual(len(out.splitlines()), 1)
        self.assertIn("'Suche'", out)

    def test_shot_runs_drm_shot_next_to_the_script(self):
        with mock.patch.object(carmcp.subprocess, 'run') as run, \
                mock.patch.object(carmcp.os, 'makedirs'):
            self.run_main(SCREEN, 'shot', 'optionen')
        cmd = run.call_args.args[0]
        self.assertEqual(cmd[:2], ['sudo', 'python3'])
        self.assertTrue(cmd[2].endswith('/drm_shot.py'))
        self.assertTrue(cmd[3].endswith('/shots/optionen.png'))


if __name__ == '__main__':
    unittest.main()

#!/usr/bin/env python3
"""Drives carnine-frontend over its MCP socket and takes pictures.

Only with a frontend built with MCP (CARNINE_FRONTEND_MCP=1) and started
with --enable-mcp. Run as the user of the frontend (not root).

  carmcp.py nodes [filter]        nodes with label/role/rect/actions
  carmcp.py tap <label>           tap the node with exactly/starting with/
                                  containing this label
  carmcp.py stap <label>          the same as a semantics action
  carmcp.py tapxy <x> <y>         tap a point (panel pixels)
  carmcp.py long <label>          long press (semantics action)
  carmcp.py text <label> <text>   set the text of a field (ui_set_text)
  carmcp.py type <text>           type on the app's on-screen keyboard
  carmcp.py shot <name>           picture to ~/shots/<name>.png (drm_shot.py)

The socket is CARMCP_SOCK, by default
/run/user/<uid>/ivi-homescreen/mcp.sock.
"""
import http.client
import json
import os
import socket
import subprocess
import sys
import time

SOCK = os.environ.get(
    'CARMCP_SOCK', f'/run/user/{os.getuid()}/ivi-homescreen/mcp.sock')
DRM_SHOT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        'drm_shot.py')
# The label of the space bar on the app's (German) on-screen keyboard.
SPACE_KEY = 'Leerzeichen'


class UnixConn(http.client.HTTPConnection):
    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.connect(SOCK)


_id = 0


def payload(body):
    """The JSON-RPC answer from a plain JSON or a server-sent-events body."""
    if 'data:' in body[:20] or body.startswith('event:'):
        body = [line[5:] for line in body.splitlines()
                if line.startswith('data:')][-1]
    return json.loads(body)


def call(method, params):
    global _id
    _id += 1
    c = UnixConn('localhost')
    c.request('POST', '/', json.dumps({'jsonrpc': '2.0', 'id': _id,
                                       'method': method, 'params': params}),
              {'Content-Type': 'application/json',
               'Accept': 'application/json, text/event-stream'})
    return payload(c.getresponse().read().decode())


def tool(name, args):
    r = call('tools/call', {'name': name, 'arguments': args})
    text = r['result']['content'][0]['text']
    try:
        return json.loads(text)
    except ValueError:
        return text


def nodes():
    s = tool('ui_snapshot', {})
    return [n for v in s['views'] for n in v['result']['nodes']]


def match(ns, label):
    """First node whose label is, starts with or contains `label` (in that
    order of preference), or None. Line breaks in labels count as ' | '."""
    ns = [n for n in ns if n.get('label')]
    for pred in (lambda lb: lb == label, lambda lb: lb.startswith(label),
                 lambda lb: label in lb):
        hit = [n for n in ns if pred(n['label'].replace('\n', ' | '))]
        if hit:
            return hit[0]
    return None


def find(label):
    n = match(nodes(), label)
    if n is None:
        sys.exit(f'no node with label {label!r}')
    return n


def center(n):
    r = n['rect']
    return (r.get('x', r.get('left', 0)) + r.get('w', r.get('width', 0)) / 2,
            r.get('y', r.get('top', 0)) + r.get('h', r.get('height', 0)) / 2)


def keyboard(ns):
    """Key per character on the app's on-screen keyboard. A key is a button
    whose label ends in one character ('A\\nA'); the space bar is SPACE_KEY.
    Keys are lower case, the first button wins."""
    keys = {}
    for n in ns:
        lb = (n.get('label') or '').split('\n')[-1]
        if n.get('role') == 'button' and len(lb) == 1:
            keys.setdefault(lb.lower(), n)
        elif lb == SPACE_KEY:
            keys[' '] = n
    return keys


def type_text(text, pause=0.25):
    # ui_set_text does not reach the app's own keyboard field, so tap keys.
    for ch in text:
        n = keyboard(nodes()).get(ch.lower())
        if not n:
            sys.exit(f'no key for {ch!r}')
        x, y = center(n)
        tool('ui_tap_at', {'x': x, 'y': y})
        time.sleep(pause)


def main(argv):
    if not argv:
        sys.exit(__doc__)
    call('initialize', {'protocolVersion': '2025-06-18', 'capabilities': {},
                        'clientInfo': {'name': 'carmcp', 'version': '1'}})
    cmd, args = argv[0], argv[1:]
    if cmd == 'nodes':
        f = args[0] if args else ''
        for n in nodes():
            lb = (n.get('label') or '').replace('\n', ' | ')
            if f in lb or f in (n.get('role') or ''):
                print(n.get('role'), repr(lb[:70]), n.get('rect'),
                      n.get('actions'))
    elif cmd == 'tap':
        x, y = center(find(args[0]))
        print(tool('ui_tap_at', {'x': x, 'y': y}))
    elif cmd == 'stap':
        print(tool('ui_tap', {'node_id': find(args[0])['id']}))
    elif cmd == 'tapxy':
        print(tool('ui_tap_at', {'x': float(args[0]), 'y': float(args[1])}))
    elif cmd == 'long':
        n = find(args[0])
        print(n.get('actions'), tool('ui_long_press', {'node_id': n['id']}))
    elif cmd == 'text':
        n = find(args[0])
        print(tool('ui_set_text', {'node_id': n['id'], 'text': args[1]}))
    elif cmd == 'type':
        type_text(args[0])
    elif cmd == 'shot':
        os.makedirs(os.path.expanduser('~/shots'), exist_ok=True)
        out = os.path.expanduser(f'~/shots/{args[0]}.png')
        subprocess.run(['sudo', 'python3', DRM_SHOT, out], check=True)
    else:
        sys.exit(f'unknown command {cmd!r}\n{__doc__}')


if __name__ == '__main__':
    main(sys.argv[1:])

#!/usr/bin/env python3
"""clipboard-host.py: macOS end of the BamboOS clipboard bridge.

Started by scripts/try-bambo.sh. Connects to the unix socket behind the VM's
org.bambo.clipboard port and keeps the macOS pasteboard and the guest clipboard
in step. Text goes both ways. A PNG image copied in the VM, such as a
screenshot, also lands on the macOS pasteboard. It exits when QEMU closes the
socket.

    clipboard-host.py <socket>
"""
import base64
import os
import socket
import subprocess
import sys
import tempfile
import threading
import time

MAX_BYTES = 1024 * 1024
MAX_IMAGE_BYTES = 8 * 1024 * 1024
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
ENV = dict(os.environ, LANG="en_US.UTF-8", LC_ALL="en_US.UTF-8")
last = None
ready = threading.Event()
lock = threading.Lock()


def pbpaste():
    got = subprocess.run(["pbpaste"], capture_output=True, env=ENV)
    return got.stdout if got.returncode == 0 else b""


def copy_image(png):
    """Put a PNG on the macOS pasteboard. pbcopy only takes text."""
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        f.write(png)
    try:
        # The path comes from tempfile, so it holds no quote or backslash.
        script = 'set the clipboard to (read (POSIX file "%s") as «class PNGf»)' % f.name
        subprocess.run(["osascript", "-e", script], capture_output=True)
    finally:
        os.unlink(f.name)


def from_guest(sock):
    """Guest lines become the macOS pasteboard."""
    global last
    for line in sock.makefile("rb"):
        line = line.strip()
        if line == b"hello":  # the guest agent has opened the port
            ready.set()
            continue
        if line.startswith(b"img:"):
            try:
                png = base64.b64decode(line[4:], validate=True)
            except ValueError:
                continue
            if png.startswith(PNG_SIGNATURE) and len(png) <= MAX_IMAGE_BYTES:
                copy_image(png)
            continue
        try:
            text = base64.b64decode(line, validate=True)
        except ValueError:
            continue
        if not text or len(text) > MAX_BYTES:
            continue
        with lock:
            last = text
        subprocess.run(["pbcopy"], input=text, env=ENV)
    os._exit(0)  # QEMU is gone


def main():
    global last
    path = sys.argv[1]
    sock = socket.socket(socket.AF_UNIX)
    for _ in range(100):
        try:
            sock.connect(path)
            break
        except OSError:
            time.sleep(0.3)
    else:
        return 1
    threading.Thread(target=from_guest, args=(sock,), daemon=True).start()

    # Nothing is sent until the guest agent says hello, and what is on the
    # pasteboard at that moment stays on the Mac: only later copies cross over.
    ready.wait()
    last = pbpaste()
    while True:
        time.sleep(0.5)
        text = pbpaste()
        if not text or len(text) > MAX_BYTES:
            continue
        with lock:
            if text == last:
                continue
            last = text
        try:
            sock.sendall(base64.b64encode(text) + b"\n")
        except OSError:
            return 0


if __name__ == "__main__":
    sys.exit(main())

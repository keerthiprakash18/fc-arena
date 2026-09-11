"""Serve the built Flutter web app with correct MIME types.

Usage:
    python serve_web.py            # serves on http://localhost:8080
    python serve_web.py 9000       # custom port

Why this exists: Flutter web loads CanvasKit as a .wasm file and the app as
.mjs modules. Python's stdlib http.server guesses those Content-Types
inconsistently across versions, and a wrong type makes the engine fail to boot
with a blank page. This pins them.

Build the app first:
    cd frontend && flutter build web --release --dart-define=API_BASE_URL=<api>
"""

import functools
import http.server
import mimetypes
import os
import socketserver
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "frontend", "build", "web")

MIME_TYPES = {
    ".wasm": "application/wasm",
    ".mjs": "text/javascript",
    ".js": "text/javascript",
    ".json": "application/json",
    ".webmanifest": "application/manifest+json",
    ".otf": "font/otf",
    ".ttf": "font/ttf",
    ".woff2": "font/woff2",
    ".png": "image/png",
    ".svg": "image/svg+xml",
    ".symbols": "text/plain",
}


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # The Flutter service worker caches aggressively; keep dev iteration sane.
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080

    if not os.path.isdir(ROOT):
        sys.exit(
            "No web build found at %s\n"
            "Build it first:\n"
            "  cd frontend && flutter build web --release "
            "--dart-define=API_BASE_URL=http://localhost:8000/api" % ROOT
        )

    for ext, content_type in MIME_TYPES.items():
        mimetypes.add_type(content_type, ext)

    handler = functools.partial(Handler, directory=ROOT)
    socketserver.TCPServer.allow_reuse_address = True

    with socketserver.TCPServer(("0.0.0.0", port), handler) as httpd:
        print("FC ARENA web app -> http://localhost:%d" % port)
        print("Serving %s" % ROOT)
        print("On your phone (same Wi-Fi): http://<this-machine-ip>:%d" % port)
        print("Press Ctrl+C to stop.")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nStopped.")


if __name__ == "__main__":
    main()

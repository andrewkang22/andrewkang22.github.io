"""Local preview with the same clean URLs as GitHub Pages.

/venture serves venture.html, just like on GitHub Pages. Nothing is cached, so edits
show up on reload.

    python3 tools/serve.py [port]
"""
import http.server
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def translate_path(self, path):
        fs = super().translate_path(path)
        if not os.path.exists(fs) and os.path.isfile(fs + '.html'):
            return fs + '.html'
        return fs

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()


if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8766
    http.server.ThreadingHTTPServer(('', port), Handler).serve_forever()

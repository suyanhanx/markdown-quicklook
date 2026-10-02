"""Exercise opt-in image loading on an isolated, temporary loopback server."""
import base64
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
import threading

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != '/ok.png':
            self.send_error(404)
            return
        data = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aK1cAAAAASUVORK5CYII=')
        self.send_response(200)
        self.send_header('Content-Type', 'image/png')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)
    def log_message(self, *args):
        pass
server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
try:
    html = Path('build/remote-template.html').read_text().replace('127.0.0.1:54321', f'127.0.0.1:{server.server_port}')
    Path('build/remote-live.html').write_text(html)
    with Path('build/web-remote-result.json').open('w') as output:
        subprocess.run(['build/web-rendering-tests', 'build/remote-live.html'], stdout=output, check=True, timeout=50)
finally:
    server.shutdown()
    server.server_close()
    thread.join()

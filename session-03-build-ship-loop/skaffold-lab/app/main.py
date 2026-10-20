import os
import socket
from http.server import BaseHTTPRequestHandler, HTTPServer

VERSION = "v1"


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/healthz":
            body = "ok"
        else:
            # message.txt is read per request, so file sync can update it without a rebuild
            with open("message.txt") as f:
                message = f.read().strip()
            body = f"{message}\napp version: {VERSION}\npod: {socket.gethostname()}\nenv: {os.getenv('APP_ENV', 'dev')}"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write((body + "\n").encode())


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()

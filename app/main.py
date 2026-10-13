"""luul-orders-service: a small orders/pricing API used for the team trunk-based project.

Endpoints:
  GET /health                      -> {"status": "ok"}
  GET /version                     -> version + git commit
  GET /price?amount=100&code=LUUL10 -> {"amount": 100.0, "code": "LUUL10", "total": 90.0}
"""
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

from app.pricing import calculate_total

VERSION = "1.0.0"
FLAGS_FILE = Path(os.environ.get("FLAGS_FILE", Path(__file__).parent.parent / "config" / "flags.json"))


def load_flags():
    """Flags come from config/flags.json; FLAG_<NAME>=true|false overrides per environment."""
    try:
        flags = json.loads(FLAGS_FILE.read_text())
    except (OSError, json.JSONDecodeError):
        flags = {}
    for name in list(flags):
        env_value = os.environ.get(f"FLAG_{name.upper()}")
        if env_value is not None:
            flags[name] = env_value.lower() == "true"
    return flags


def route(raw_path):
    """Return (status_code, body_dict) for a request path."""
    url = urlparse(raw_path)
    if url.path == "/health":
        return 200, {"status": "ok"}
    if url.path == "/version":
        return 200, {"version": VERSION, "commit": os.environ.get("GIT_SHA", "local")}
    if url.path == "/price":
        query = parse_qs(url.query)
        try:
            amount = float(query.get("amount", ["0"])[0])
            code = query.get("code", [None])[0]
            total = calculate_total(amount, code, load_flags())
        except ValueError as err:
            return 400, {"error": str(err)}
        return 200, {"amount": amount, "code": code, "total": total}
    return 404, {"error": "not found"}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        status, body = route(self.path)
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *args):  # keep test output clean
        pass


def make_server(port):
    return HTTPServer(("0.0.0.0", port), Handler)


def main():
    port = int(os.environ.get("PORT", "8080"))
    print(f"luul-orders-service v{VERSION} listening on :{port}")
    make_server(port).serve_forever()


if __name__ == "__main__":
    main()

"""End-to-end API tests - owned by QA (see CODEOWNERS: /tests/e2e/ needs QA review).

They start the real HTTP server, or test a deployed environment when BASE_URL is set:
    BASE_URL=https://staging.example.com python3 -m unittest discover -s tests/e2e -t .
"""
import json
import os
import threading
import unittest
import urllib.error
import urllib.request

from app import main

BASE_URL = os.environ.get("BASE_URL")


def get(path):
    try:
        with urllib.request.urlopen(BASE + path, timeout=5) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as err:
        return err.code, json.loads(err.read())


def setUpModule():
    global BASE, SERVER
    if BASE_URL:
        BASE, SERVER = BASE_URL.rstrip("/"), None
        return
    SERVER = main.make_server(0)  # port 0 = any free port
    threading.Thread(target=SERVER.serve_forever, daemon=True).start()
    BASE = f"http://127.0.0.1:{SERVER.server_address[1]}"


def tearDownModule():
    if SERVER:
        SERVER.shutdown()
        SERVER.server_close()


class ApiTests(unittest.TestCase):
    def test_health(self):
        self.assertEqual(get("/health"), (200, {"status": "ok"}))

    def test_price_with_code(self):
        status, body = get("/price?amount=200&code=LUUL10")
        self.assertEqual(status, 200)
        self.assertEqual(body["total"], 180)

    def test_bad_amount_is_400_not_500(self):
        status, _ = get("/price?amount=abc")
        self.assertEqual(status, 400)

    def test_unknown_path_is_404(self):
        status, _ = get("/nope")
        self.assertEqual(status, 404)


if __name__ == "__main__":
    unittest.main()

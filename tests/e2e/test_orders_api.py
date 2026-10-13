"""E2E tests for /orders/summary (written by QA). Uses the shared helpers from test_api.py.

Locally the flag is switched on for this process. Against staging (BASE_URL set), the
flag must be ON in deploy/staging.env, which is the platform part of the lab.
"""
import os
import unittest
from unittest import mock

from tests.e2e import test_api
from tests.e2e.test_api import get

setUpModule = test_api.setUpModule
tearDownModule = test_api.tearDownModule


@mock.patch.dict(os.environ, {"FLAG_ORDERS_API": "true"})
class OrdersApiTests(unittest.TestCase):
    def test_summary_with_code(self):
        status, body = get("/orders/summary?items=100,50&code=LUUL10")
        self.assertEqual(status, 200)
        self.assertEqual(body, {"items": 2, "subtotal": 150.0, "code": "LUUL10", "total": 135.0})

    def test_missing_items_is_400(self):
        self.assertEqual(get("/orders/summary")[0], 400)

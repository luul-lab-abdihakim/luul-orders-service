"""Unit tests for the order summary (written by the developer, BEFORE the code)."""
import os
import unittest
from unittest import mock

from app import main
from app.orders import summarize


class SummarizeTests(unittest.TestCase):
    def test_adds_items(self):
        self.assertEqual(summarize([100, 50.5])["subtotal"], 150.5)

    def test_applies_discount_to_subtotal(self):
        self.assertEqual(summarize([100, 100], "LUUL10")["total"], 180)

    def test_empty_order_rejected(self):
        with self.assertRaises(ValueError):
            summarize([])


class RouteFlagTests(unittest.TestCase):
    def test_hidden_when_flag_off(self):
        with mock.patch.dict(os.environ, {"FLAG_ORDERS_API": "false"}):
            self.assertEqual(main.route("/orders/summary?items=10")[0], 404)

    def test_works_when_flag_on(self):
        with mock.patch.dict(os.environ, {"FLAG_ORDERS_API": "true"}):
            status, body = main.route("/orders/summary?items=100,50&code=LUUL10")
        self.assertEqual((status, body["total"]), (200, 135))

    def test_bad_input_is_400(self):
        with mock.patch.dict(os.environ, {"FLAG_ORDERS_API": "true"}):
            self.assertEqual(main.route("/orders/summary?items=abc")[0], 400)


if __name__ == "__main__":
    unittest.main()

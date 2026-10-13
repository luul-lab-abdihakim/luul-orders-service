"""Unit tests - owned by the developers."""
import unittest

from app.pricing import calculate_total


class PricingTests(unittest.TestCase):
    def test_no_code_no_discount(self):
        self.assertEqual(calculate_total(100), 100)

    def test_luul10_gives_10_percent(self):
        self.assertEqual(calculate_total(100, "LUUL10"), 90)

    def test_code_is_case_insensitive(self):
        self.assertEqual(calculate_total(100, "luul10"), 90)

    def test_unknown_code_is_ignored(self):
        self.assertEqual(calculate_total(100, "FAKE"), 100)

    def test_negative_amount_rejected(self):
        with self.assertRaises(ValueError):
            calculate_total(-1)

    def test_discounts_v2_off_by_default(self):
        self.assertEqual(calculate_total(1000), 1000)

    def test_discounts_v2_adds_5_percent_on_big_orders(self):
        self.assertEqual(calculate_total(1000, "LUUL10", {"discounts_v2": True}), 850)


if __name__ == "__main__":
    unittest.main()

"""Pricing rules for Luul orders.

Owned by the developers. Changes need a review from the lead engineers (see CODEOWNERS).
"""

DISCOUNT_CODES = {
    "LUUL10": 10,   # 10% off
    "WELCOME5": 5,  # 5% off
}


def calculate_total(amount, code=None, flags=None):
    """Return the price after discount, rounded to 2 decimals.

    discounts_v2 (feature flag): orders of 500 or more get an extra 5% off.
    It is merged to trunk but stays OFF until QA signs it off.
    """
    if amount < 0:
        raise ValueError("amount must be positive")
    flags = flags or {}

    percent = DISCOUNT_CODES.get((code or "").upper(), 0)
    if flags.get("discounts_v2") and amount >= 500:
        percent += 5

    return round(amount * (100 - percent) / 100, 2)

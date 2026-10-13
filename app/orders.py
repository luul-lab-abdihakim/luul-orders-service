"""Order summary (ticket LUUL-400). Hidden behind the feature flag: orders_api."""
from app.pricing import calculate_total


def summarize(prices, code=None, flags=None):
    """Add up item prices, then apply the discount code to the subtotal."""
    if not prices:
        raise ValueError("at least one item price is required")
    if any(p < 0 for p in prices):
        raise ValueError("item prices must be positive")
    subtotal = round(sum(prices), 2)
    return {
        "items": len(prices),
        "subtotal": subtotal,
        "code": code,
        "total": calculate_total(subtotal, code, flags),
    }

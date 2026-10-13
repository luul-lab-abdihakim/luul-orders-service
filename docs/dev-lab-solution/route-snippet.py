# 1) At the top of app/main.py, next to the other import:
from app.orders import summarize

# 2) Inside route(), BEFORE the final `return 404, ...` line:
    if url.path == "/orders/summary":
        flags = load_flags()
        if not flags.get("orders_api"):          # feature OFF -> behave as if it doesn't exist
            return 404, {"error": "not found"}
        query = parse_qs(url.query)
        try:
            raw = query.get("items", [""])[0]    # e.g. "100,50.5"
            prices = [float(p) for p in raw.split(",") if p.strip()]
            summary = summarize(prices, query.get("code", [None])[0], flags)
        except ValueError as err:
            return 400, {"error": str(err)}
        return 200, summary

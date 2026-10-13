# The developer's view and the DevOps view

As a DevOps / platform engineer you serve developers. To help them, you must understand **their** work: the code, the tests, and what they see when something fails. This guide has 4 parts:

1. **The app explained**: every file in simple words
2. **Developer lab**: build a real feature yourself (tested end to end)
3. **Two points of view**: the same change, step by step, as developer and as DevOps
4. **When it goes wrong**: what each side sees and does

---

## Part 1: The app explained

`luul-orders-service` is a small web API. You send it a price and a discount code, and it answers with JSON.

```
curl "localhost:8080/price?amount=200&code=LUUL10"
→ {"amount": 200.0, "code": "LUUL10", "total": 180.0}
```

### What happens on one request
```
Browser / curl / QA test
   │  GET /price?amount=200&code=LUUL10
   ▼
Handler.do_GET()          app/main.py  - receives the HTTP request
   │
   ▼
route(path)               app/main.py  - looks at the URL and decides what to do
   │
   ├─► load_flags()       app/main.py  - reads config/flags.json, then FLAG_* env vars override it
   │
   └─► calculate_total()  app/pricing.py - the business rule (discount codes, discounts_v2)
   │
   ▼
JSON response             {"total": 180.0}   with status 200 / 400 / 404
```

### Every file, in simple words

| File | What it does | Who changes it |
|---|---|---|
| `app/pricing.py` | **Business logic.** `DISCOUNT_CODES` maps codes to percentages. `calculate_total()` applies them. If the `discounts_v2` flag is on, orders of 500 or more get an extra 5% | Developers (lead must approve) |
| `app/main.py` | **The web layer.** `route()` maps URLs to code: `/health`, `/version`, `/price`. It turns bad input into **400** instead of crashing (a crash would be a **500**) | Developers |
| `config/flags.json` | **Feature switches** for all environments. `false` = hidden | Lead + QA approve |
| `deploy/<env>.env` | **Per-environment settings.** `FLAG_X=true` here wins over flags.json, but only in that environment | Platform + leads |
| `tests/unit/` | **Unit tests**: call Python functions directly. Fast (milliseconds), no server | Developers |
| `tests/e2e/` | **End-to-end tests**: start the real HTTP server and call it like a customer would. With `BASE_URL=...` they test a deployed environment instead | QA |
| `Dockerfile` | Packs the app into an image: Python 3.12, copy `app/` and `config/`, run as a non-root user, health check on `/health` | Platform |
| `Makefile` | Shortcuts: `make test`, `make run`, `make build` | Everyone |

### Three ideas every developer (and you) must know
- **HTTP status codes:** 200 = OK, 400 = the client sent bad input, 404 = not found (or the feature is hidden), 500 = our code crashed. A 500 is always a bug.
- **`/health`** is for machines: Docker, Kubernetes and CI ask "are you alive?". **`/version`** tells you *which commit* is running. It's the first thing to check in an incident.
- **Configuration is not code.** The same image runs everywhere, and only settings (env files, flags) change per environment.

---

## Part 2: Developer lab, build a feature yourself

**Ticket LUUL-400:** *"As a customer, I want an order summary: send several item prices and a code, get the subtotal and total."*
Endpoint: `GET /orders/summary?items=100,50&code=LUUL10` → `{"items": 2, "subtotal": 150.0, "code": "LUUL10", "total": 135.0}`.
It's not finished for customers yet, so it goes **behind a flag**: `orders_api`.

The reference solution is in `docs/dev-lab-solution/`. Try it yourself first, then compare.

```bash
cd ~/wezva-ai-driven-bootcamp/git-github/luul-team-project
./sim/reset.sh                         # (after ./sim/create-team.sh --local once)
W=~/wezva-ai-driven-bootcamp/git-github/luul-team-workspace
```

### Step 1: You are Alice (developer). Start from the latest trunk
```bash
cd $W/alice-dev
git switch main && git pull
git switch -c feat/LUUL-400-order-summary
```

### Step 2: Add the flag, OFF by default (it's safe to merge right away)
Edit `config/flags.json`:
```json
{
  "discounts_v2": false,
  "orders_api": false
}
```
```bash
git commit -am "feat(LUUL-400): add orders_api flag (off)"
```

### Step 3: Write the test FIRST (test-driven development)
Create `tests/unit/test_orders.py` (copy it from `docs/dev-lab-solution/tests/unit/`). Read it: it describes what the feature must do.
```bash
make test-unit        # FAILS: ModuleNotFoundError: No module named 'app.orders'  <- expected!
```

### Step 4: Write the code until the tests pass
Create `app/orders.py` (the solution is in `docs/dev-lab-solution/app/orders.py`):
```python
def summarize(prices, code=None, flags=None):
    if not prices:
        raise ValueError("at least one item price is required")
    ...
    subtotal = round(sum(prices), 2)
    return {"items": len(prices), "subtotal": subtotal, "code": code,
            "total": calculate_total(subtotal, code, flags)}
```
Connect it to the web layer in `app/main.py`. See `docs/dev-lab-solution/route-snippet.py`: one import, and one `if url.path == "/orders/summary":` block that returns **404 when the flag is off**.
```bash
make test-unit        # Ran 13 tests ... OK
git add -A            # -A: include the NEW file app/orders.py (see "When it goes wrong", case 2)
git commit -m "feat(LUUL-400): order summary endpoint behind orders_api flag"
```

### Step 5: Try it like a user
```bash
make run                                   # terminal 1: flag OFF
curl "localhost:8080/orders/summary?items=100,50&code=LUUL10"
# {"error": "not found"}                   <- hidden, as planned

FLAG_ORDERS_API=true make run              # terminal 1: flag ON (only for this process)
curl "localhost:8080/orders/summary?items=100,50&code=LUUL10"
# {"items": 2, "subtotal": 150.0, "code": "LUUL10", "total": 135.0}
```
With Docker running: `make build` then `docker run --rm -p 8080:8080 -e FLAG_ORDERS_API=true luul-orders-service:<sha>`.

```bash
git push -u origin feat/LUUL-400-order-summary     # GitHub: gh pr create --fill
```

### Step 6: You are Sara (QA). Add end-to-end tests on the same branch
```bash
cd $W/sara-qa
git fetch && git switch feat/LUUL-400-order-summary
cp ~/wezva-ai-driven-bootcamp/git-github/luul-team-project/docs/dev-lab-solution/tests/e2e/test_orders_api.py tests/e2e/
make test-e2e                                       # Ran 6 tests ... OK
git add -A && git commit -m "test(LUUL-400): e2e for order summary" && git push
```

### Step 7: You are you (platform). Switch the feature on in dev and staging only
QA's tests will also run **against staging** in CD, so the feature must be ON there. Prod stays OFF.
```bash
cd $W/you-platform
git switch main && git pull
git switch -c chore/LUUL-401-orders-flag-envs
echo "FLAG_ORDERS_API=true" >> deploy/dev.env
echo "FLAG_ORDERS_API=true" >> deploy/staging.env
git commit -am "chore(LUUL-401): orders_api ON in dev + staging"
git push origin HEAD:main                           # GitHub: PR, platform + lead approve
```

### Step 8: Back to Alice. Update from trunk and merge
```bash
cd $W/alice-dev
git pull --rebase                  # get Sara's e2e commit
git fetch origin && git rebase origin/main
make test                          # unit 13 OK + e2e 6 OK
git push --force-with-lease
git push origin HEAD:main          # GitHub: squash merge the PR after checks + review
```

### Step 9: Release to customers (later)
When QA has signed off in staging: a PR that sets `"orders_api": true` in `config/flags.json`, approved by **lead + QA** (CODEOWNERS). Weeks later, a cleanup PR removes the flag and the `if not flags.get(...)` check.

---

## Part 3: Two points of view, the same change

| Step | Developer does / sees | DevOps / platform does / sees |
|---|---|---|
| Start | Branch from latest main, read the ticket | Made sure `main` is protected and CI is fast, so small PRs are cheap |
| Flag | Adds `orders_api: false` | Owns the flag mechanism and `deploy/<env>.env` per environment |
| Code + tests | TDD: test fails, then code, then test passes. Runs `make test` locally | Gave them `make test`, which is **the same command CI runs**, so "works on my laptop" means "works in CI" |
| Push / PR | Opens a PR, waits for checks | CI runs `unit-tests`, `e2e-tests`, `docker-build`, `secret-scan`. You watch duration and flakiness |
| Review | Gets review from CODEOWNERS | Designed CODEOWNERS: leads for pricing, QA for e2e, platform for pipelines |
| QA | Sara adds e2e tests on the branch | e2e is a **required** check, and also runs against staging in CD |
| Settings | Doesn't touch environments | Turns the flag on in `dev.env` + `staging.env` with a reviewed PR |
| Merge | Rebase, green, squash merge | Merge queue / up-to-date rule keeps main green |
| Deploy | Checks `/version` in dev to see their commit is live | CD builds one image `:<sha>`, deploys dev → staging (+ e2e) → waits for prod approval |
| Release | Lead + QA approve the flag-on PR | Monitors errors and latency after release. Rollback = flag off or redeploy previous SHA |
| Cleanup | Removes the flag code | Removes the flag from the env files |

**The big idea:** developers own *what* the code does. DevOps owns *how safely and quickly* it gets to users. You meet in the PR and in the pipeline.

---

## Part 4: When it goes wrong (both sides)

### Case 1: "QA's tests pass on my laptop but fail in staging" (tested)
- **Developer sees:** CD job `deploy-staging` failed: `AssertionError: 404 != 200` on `/orders/summary`.
- **Cause:** the code is fine, but the **flag is OFF in staging**. Locally the test turned it on, and `deploy/staging.env` didn't.
- **DevOps checks:**
  ```bash
  cat deploy/staging.env                                 # is FLAG_ORDERS_API=true there?
  curl https://staging.../version                        # is the right commit even deployed?
  ```
- **Fix:** a PR adding `FLAG_ORDERS_API=true` to `deploy/staging.env` (Part 2, step 7).
- **Lesson:** *same code, different config.* Always compare configuration between environments first.

### Case 2: "It works on my laptop but CI fails" (tested)
- **Developer sees:** CI `unit-tests` fails with `ModuleNotFoundError: No module named 'app.helpers'`. On the laptop everything is green.
- **Cause:** the new file was never committed. `git commit -am` only includes files Git **already tracks**. CI starts from a **clean clone**, so the file isn't there.
- **Check:**
  ```bash
  git status --short          # ?? app/helpers.py   <- "??" = untracked, never committed
  ```
- **Fix:** `git add app/helpers.py && git commit -m "..." && git push`.
- **Lesson:** CI is a clean room. Other causes of this same symptom: a local env var (`env | grep FLAG_`), a different Python version (CI pins 3.12), or a package installed only on the laptop.

### Case 3: "It works locally but not in Docker"
- **Developer sees:** the container starts, then the health check fails, or a file is missing.
- **DevOps checks:**
  ```bash
  docker logs <container>                        # the error message
  docker run --rm -it <image> ls -R /srv         # is every file I need INSIDE the image?
  docker run --rm -it <image> env | grep FLAG    # which settings does the container see?
  docker exec -it <container> python -c "import urllib.request;print(urllib.request.urlopen('http://localhost:8080/health').read())"
  ```
- **Common causes:** a new folder not in the Dockerfile's `COPY` lines (ours copies only `app/` and `config/`), excluded by `.dockerignore`, the server listening on `127.0.0.1` instead of `0.0.0.0` (ours uses `0.0.0.0`), or a missing env var.

### Case 4: "My PR can't be merged"
| Message on the PR | Meaning | Developer fix |
|---|---|---|
| *Review required* | A CODEOWNER hasn't approved | Ask the team shown in the PR |
| *This branch is out-of-date* | The ruleset requires the latest main | Click **Update branch**, or `git fetch && git rebase origin/main && git push --force-with-lease` |
| *Some checks were not successful* | A required check failed | Open **Details** on the red check and read the log |
| *Changes requested* / unresolved conversations | Reviewer wants changes | Push fixes, resolve threads |

**DevOps:** explain the rule. Don't bypass it. If a rule slows everyone down for no reason, change it with a PR.

### Case 5: "The pipeline is too slow, I wait 25 minutes"
- **Developer:** loses focus, makes bigger PRs to wait less often, which is bad for trunk-based development.
- **DevOps measures first** (`gh run list`, `gh run view <id>` shows time per job), then caches dependencies and Docker layers, runs jobs in parallel, uses path filters, splits slow tests, and uses `concurrency` to cancel outdated runs.
- **Goal:** PR checks in under 10 minutes. That's what keeps PRs small.

### Case 6: "Port 8080 is already in use"
```bash
lsof -i :8080            # who is using the port?
kill <PID>               # or run on another port:
PORT=8081 make run
```

### Case 7: "The bug only happens in prod"
1. `curl https://prod.../version`: which commit is running? Is it the one you think?
2. Compare settings: `diff deploy/staging.env deploy/prod.env`, and `config/flags.json`.
3. Check logs and metrics around the deploy time.
4. Reproduce locally with prod's settings: `set -a; . deploy/prod.env; set +a; make run`.
5. Fix forward with a test, or roll back (flag off, or redeploy the previous SHA).

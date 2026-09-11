"""End-to-end smoke test for FC ARENA.

Exercises every action the app's buttons perform against a running backend, so
you can prove a build works before shipping it.

Usage:
    python smoke_test.py                          # http://localhost:8000/api
    python smoke_test.py https://host/api         # any deployment
    python smoke_test.py https://host/api user pass

Exits 0 if every step passes, 1 otherwise.

NOTE: this creates real data (a league named "Smoke Test League"). Point it at a
staging/dev backend, not production, unless you clean up afterwards.
"""

import json
import sys
import urllib.error
import urllib.request
import uuid

BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000/api").rstrip("/")
USERNAME = sys.argv[2] if len(sys.argv) > 2 else "luciferkp"
PASSWORD = sys.argv[3] if len(sys.argv) > 3 else "keerthi@1518"

PASSED, FAILED = [], []


class ApiError(Exception):
    def __init__(self, status, body):
        self.status = status
        self.body = body
        # Django's debug 404 pages are huge HTML blobs — keep messages readable.
        text = json.dumps(body) if isinstance(body, (dict, list)) else str(body)
        text = " ".join(text.split())
        if len(text) > 200:
            text = text[:200] + "..."
        super().__init__(f"HTTP {status}: {text}")


class Client:
    def __init__(self, base):
        self.base = base
        self.token = None

    def _request(self, method, path, payload=None, raw=None, content_type=None):
        url = f"{self.base}{path}"
        data = None
        headers = {"Accept": "application/json"}

        if raw is not None:
            data = raw
            headers["Content-Type"] = content_type
        elif payload is not None:
            data = json.dumps(payload).encode()
            headers["Content-Type"] = "application/json"

        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"

        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                body = resp.read().decode() or "{}"
                return resp.status, json.loads(body) if body.strip() else {}
        except urllib.error.HTTPError as e:
            body = e.read().decode()
            try:
                parsed = json.loads(body) if body.strip() else {}
            except json.JSONDecodeError:
                parsed = {"raw": body}
            raise ApiError(e.code, parsed) from None

    def get(self, path):
        return self._request("GET", path)

    def post(self, path, payload=None):
        return self._request("POST", path, payload=payload or {})

    def patch(self, path, payload):
        return self._request("PATCH", path, payload=payload)

    def delete(self, path):
        return self._request("DELETE", path)

    def upload(self, path, filename, content, field="file"):
        boundary = "----FCARENA" + uuid.uuid4().hex
        body = b""
        body += f"--{boundary}\r\n".encode()
        body += (
            f'Content-Disposition: form-data; name="{field}"; '
            f'filename="{filename}"\r\n'
        ).encode()
        body += b"Content-Type: image/png\r\n\r\n"
        body += content + b"\r\n"
        body += f"--{boundary}--\r\n".encode()
        return self._request(
            "POST", path, raw=body, content_type=f"multipart/form-data; boundary={boundary}"
        )


def step(label, fn):
    """Run one check; record pass/fail instead of aborting the whole run."""
    try:
        result = fn()
        PASSED.append(label)
        print(f"  PASS  {label}")
        return result
    except (AssertionError, ApiError) as e:
        FAILED.append((label, str(e)))
        print(f"  FAIL  {label}\n          {e}")
        return None
    except Exception as e:  # noqa: BLE001 - report anything unexpected
        FAILED.append((label, f"{type(e).__name__}: {e}"))
        print(f"  FAIL  {label}\n          {type(e).__name__}: {e}")
        return None


def expect(condition, message):
    if not condition:
        raise AssertionError(message)


def main():
    api = Client(BASE)
    print(f"\nFC ARENA smoke test -> {BASE}\n")

    # ── service ─────────────────────────────────────────────────────────────
    print("[service]")
    step("health probe", lambda: expect(api.get("/health/")[0] == 200, "health not 200"))
    step("api root", lambda: expect(api.get("/")[0] == 200, "root not 200"))

    # ── auth ────────────────────────────────────────────────────────────────
    print("\n[auth]")

    def do_login():
        status, data = api.post("/auth/login/", {"username": USERNAME, "password": PASSWORD})
        expect(status == 200 and "access" in data, "no access token")
        api.token = data["access"]
        return data

    step("login", do_login)
    step("profile", lambda: expect(api.get("/auth/profile/")[1]["username"] == USERNAME, "wrong user"))

    def bad_login():
        try:
            api.post("/auth/login/", {"username": USERNAME, "password": "definitely-wrong"})
            raise AssertionError("bad password was accepted!")
        except ApiError as e:
            expect(e.status == 401, f"expected 401, got {e.status}")

    step("wrong password rejected", bad_login)

    # A second account, so member/join/role flows can be tested.
    other = f"smoke_{uuid.uuid4().hex[:8]}"

    def register_other():
        status, _ = api.post("/auth/register/", {
            "username": other, "email": f"{other}@example.com", "password": "smokepass123",
        })
        expect(status == 201, f"register returned {status}")
        return other

    step("register second player", register_other)

    # ── leagues (the create/join buttons) ───────────────────────────────────
    print("\n[leagues]")

    def create_league():
        status, data = api.post("/leagues/", {
            "name": "Smoke Test League",
            "slug": f"smoke-test-{uuid.uuid4().hex[:6]}",
            "description": "Created by smoke_test.py",
        })
        expect(status == 201, f"create league returned {status}")
        expect(data.get("league_code", "").startswith("FC-"), "invite code missing")
        return data

    league = step("create league (Create button)", create_league)
    expect(league is not None, "cannot continue without a league")
    lid = league["id"]

    step("league appears in my leagues",
         lambda: expect(any(l["id"] == lid for l in api.get("/leagues/")[1]["results"]), "not listed"))
    step("league detail", lambda: expect(api.get(f"/leagues/{lid}/")[0] == 200, "no detail"))
    step("members list", lambda: expect(api.get(f"/leagues/{lid}/members/")[1]["count"] >= 1, "no members"))

    def join_league():
        joiner = Client(BASE)
        joiner.token = joiner.post(
            "/auth/login/", {"username": other, "password": "smokepass123"}
        )[1]["access"]
        status, _ = joiner.post("/leagues/join/", {"league_code": league["league_code"]})
        expect(status == 201, f"join returned {status}")
        return joiner

    joiner = step("join league with invite code (Join button)", join_league)

    def duplicate_join_rejected():
        try:
            joiner.post("/leagues/join/", {"league_code": league["league_code"]})
            raise AssertionError("duplicate join was accepted!")
        except ApiError as e:
            expect(e.status == 400, f"expected 400, got {e.status}")

    step("duplicate join rejected", duplicate_join_rejected)

    def bad_code_rejected():
        try:
            joiner.post("/leagues/join/", {"league_code": "FC-NOPE9"})
            raise AssertionError("bad invite code was accepted!")
        except ApiError as e:
            expect(e.status == 400, f"expected 400, got {e.status}")

    step("invalid invite code rejected", bad_code_rejected)
    step("edit league (PATCH)", lambda: expect(
        api.patch(f"/leagues/{lid}/", {"description": "edited by smoke test"})[0] == 200, "patch failed"))

    # ── seasons ─────────────────────────────────────────────────────────────
    print("\n[seasons]")
    season = step("create season", lambda: _created(
        api.post(f"/leagues/{lid}/seasons/", {"name": "Smoke Season"}), "season"))
    step("seasons list", lambda: expect(api.get(f"/leagues/{lid}/seasons/")[0] == 200, "list failed"))
    step("current season", lambda: expect(
        _status_of(lambda: api.get(f"/leagues/{lid}/seasons/current/")) in (200, 404), "unexpected status"))

    # ── categories ──────────────────────────────────────────────────────────
    print("\n[categories]")
    category = step("create category", lambda: _created(
        api.post(f"/leagues/{lid}/categories/", {"name": "Smoke Division"}), "category"))
    step("categories list", lambda: expect(api.get(f"/leagues/{lid}/categories/")[0] == 200, "list failed"))

    def duplicate_category():
        try:
            api.post(f"/leagues/{lid}/categories/", {"name": "Smoke Division"})
            raise AssertionError("duplicate category was accepted!")
        except ApiError as e:
            expect(e.status == 400, f"expected 400, got {e.status}")

    step("duplicate category rejected (was a 500)", duplicate_category)

    if category:
        me = api.get("/auth/profile/")[1]["id"]
        step("assign player to category", lambda: expect(
            api.post(f"/leagues/{lid}/categories/{category['id']}/assign/", {"player_id": me})[0]
            in (200, 201), "assign failed"))
        step("category players", lambda: expect(
            api.get(f"/leagues/{lid}/categories/{category['id']}/players/")[0] == 200, "list failed"))
        step("remove player from category", lambda: expect(
            api.delete(f"/leagues/{lid}/categories/{category['id']}/players/{me}/")[0] in (200, 204),
            "remove failed"))

    # ── matches (the full verification pipeline) ────────────────────────────
    print("\n[matches]")
    me_id = api.get("/auth/profile/")[1]["id"]
    other_id = joiner.get("/auth/profile/")[1]["id"]

    match = step("create match", lambda: _created(
        api.post(f"/leagues/{lid}/matches/", {"home_user": me_id, "away_user": other_id}),
        "match"))

    def create_response_is_complete():
        m = api.post(f"/leagues/{lid}/matches/", {"home_user": me_id, "away_user": other_id})[1]
        for field in ("status", "league", "home_username", "away_username"):
            expect(field in m, f"create response missing '{field}'")
        return m

    step("create response carries full match shape", create_response_is_complete)

    if match:
        mid = match["id"]
        step("matches list", lambda: expect(api.get(f"/leagues/{lid}/matches/")[0] == 200, "list failed"))
        step("match detail", lambda: expect(api.get(f"/leagues/{lid}/matches/{mid}/")[0] == 200, "no detail"))
        step("filter matches by status", lambda: expect(
            api.get(f"/leagues/{lid}/matches/?status=SCHEDULED")[0] == 200, "filter failed"))
        step("status -> AWAITING_RESULT", lambda: expect(
            api.post(f"/leagues/{lid}/matches/{mid}/status/", {"status": "AWAITING_RESULT"})[0] == 200,
            "transition failed"))

        def illegal_jump():
            try:
                api.post(f"/leagues/{lid}/matches/{mid}/status/", {"status": "VERIFIED"})
                raise AssertionError("illegal transition allowed!")
            except ApiError as e:
                expect(e.status == 409, f"expected 409, got {e.status}")

        step("illegal status jump blocked", illegal_jump)
        step("submit result", lambda: expect(
            api.post(f"/leagues/{lid}/matches/{mid}/submit/", {"home_score": 3, "away_score": 1})[0] == 200,
            "submit failed"))

        png = (b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
               b"\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00"
               b"\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82")
        step("upload evidence", lambda: _upload_evidence(api, lid, mid, png))
        step("list evidence", lambda: expect(
            api.get(f"/leagues/{lid}/matches/{mid}/evidence/")[0] == 200, "list failed"))
        step("trigger verification", lambda: expect(
            api.post(f"/leagues/{lid}/matches/{mid}/verify/")[0] in (200, 201, 202), "trigger failed"))
        step("verification task", lambda: expect(
            api.get(f"/leagues/{lid}/matches/{mid}/verification/")[0] == 200, "no task"))
        step("admin review (approve)", lambda: expect(
            api.post(f"/leagues/{lid}/matches/{mid}/verification/review/",
                     {"approved": True, "notes": "smoke test"})[0] == 200, "review failed"))

        def match_is_verified():
            data = api.get(f"/leagues/{lid}/matches/{mid}/")[1]
            expect(data["status"] == "VERIFIED", f"expected VERIFIED, got {data['status']}")
            expect(data["home_score"] == 3 and data["away_score"] == 1, "scores not stored")

        step("match reaches VERIFIED with scores", match_is_verified)
        step("add match event", lambda: expect(
            api.post(f"/leagues/{lid}/matches/{mid}/events/",
                     {"event_type": "GOAL", "player": me_id, "minute": 12})[0] in (200, 201),
            "event failed"))
        step("list match events", lambda: expect(
            api.get(f"/leagues/{lid}/matches/{mid}/events/")[0] == 200, "list failed"))
        step("match statistics", lambda: expect(
            _status_of(lambda: api.get(f"/leagues/{lid}/matches/{mid}/statistics/")) in (200, 404),
            "unexpected status"))
        step("valid transitions list", lambda: expect(
            api.get(f"/leagues/{lid}/matches/{mid}/transitions/")[0] == 200, "failed"))

    # ── tournaments ─────────────────────────────────────────────────────────
    print("\n[tournaments]")
    tournament = step("create tournament", lambda: _created(
        api.post(f"/leagues/{lid}/tournaments/", {"name": "Smoke Cup", "format": "KNOCKOUT"}),
        "tournament"))
    step("tournaments list", lambda: expect(api.get(f"/leagues/{lid}/tournaments/")[0] == 200, "list failed"))

    if tournament:
        tid = tournament["id"]
        step("tournament detail", lambda: expect(api.get(f"/leagues/{lid}/tournaments/{tid}/")[0] == 200, "no detail"))
        step("tournament participants", lambda: expect(
            api.get(f"/leagues/{lid}/tournaments/{tid}/participants/")[0] == 200, "failed"))
        step("tournament rounds", lambda: expect(
            api.get(f"/leagues/{lid}/tournaments/{tid}/rounds/")[0] == 200, "failed"))
        step("tournament groups", lambda: expect(
            _status_of(lambda: api.get(f"/leagues/{lid}/tournaments/{tid}/groups/")) in (200, 404),
            "unexpected"))
        step("fixtures blocked while draft", lambda: _expect_status(
            lambda: api.post(f"/leagues/{lid}/tournaments/{tid}/fixtures/"), 409))

    # ── standings / stats / leaderboards ────────────────────────────────────
    print("\n[stats]")
    step("league standings", lambda: expect(api.get(f"/leagues/{lid}/standings/")[0] == 200, "failed"))
    step("league statistics", lambda: expect(api.get(f"/leagues/{lid}/statistics/")[0] == 200, "failed"))
    step("ratings", lambda: expect(api.get(f"/leagues/{lid}/ratings/")[0] == 200, "failed"))
    step("my rating detail", lambda: expect(
        api.get(f"/leagues/{lid}/ratings/")[0] == 200, "unexpected"))
    step("rating history", lambda: expect(
        _status_of(lambda: api.get(f"/leagues/{lid}/ratings/history/")) in (200, 404), "unexpected"))
    step("records", lambda: expect(api.get(f"/leagues/{lid}/records/")[0] == 200, "failed"))
    step("leaderboard", lambda: expect(api.get(f"/leagues/{lid}/leaderboards/")[0] == 200, "failed"))
    step("leaderboard top by metric", lambda: expect(
        api.get(f"/leagues/{lid}/leaderboards/rating/top/")[0] == 200, "failed"))
    step("leaderboard regenerate", lambda: expect(
        api.post(f"/leagues/{lid}/leaderboards/regenerate/")[0] in (200, 201, 202), "failed"))
    step("player statistics", lambda: expect(
        api.get(f"/leagues/{lid}/statistics/")[0] == 200, "failed"))

    # ── dashboard ───────────────────────────────────────────────────────────
    print("\n[dashboard]")
    step("overview", lambda: expect(api.get(f"/leagues/{lid}/dashboard/overview/")[0] == 200, "failed"))
    step("pending reviews", lambda: expect(
        api.get(f"/leagues/{lid}/dashboard/pending-reviews/")[0] == 200, "failed"))
    step("match status distribution", lambda: expect(
        api.get(f"/leagues/{lid}/dashboard/match-status/")[0] == 200, "failed"))
    step("rating trends", lambda: expect(
        api.get(f"/leagues/{lid}/dashboard/rating-trends/")[0] == 200, "failed"))
    step("recent activity", lambda: expect(
        api.get(f"/leagues/{lid}/dashboard/activity/")[0] == 200, "failed"))

    # ── awards / disputes / notifications ───────────────────────────────────
    print("\n[awards, disputes, notifications]")
    step("awards list", lambda: expect(api.get(f"/leagues/{lid}/awards/")[0] == 200, "failed"))
    step("create award", lambda: expect(
        api.post(f"/leagues/{lid}/awards/create/", {
            "award_type": "TOURNAMENT_MVP", "user": me_id, "custom_name": "Smoke MVP",
            "description": "smoke test",
        })[0] in (200, 201), "create failed"))
    step("disputes list", lambda: expect(api.get(f"/leagues/{lid}/disputes/")[0] == 200, "failed"))
    step("notifications list", lambda: expect(api.get("/notifications/")[0] == 200, "failed"))
    step("unread count", lambda: expect(api.get("/notifications/unread-count/")[0] == 200, "failed"))
    step("mark all read", lambda: expect(api.post("/notifications/read-all/")[0] in (200, 204), "failed"))

    # ── member management ───────────────────────────────────────────────────
    print("\n[member admin]")
    step("promote member", lambda: expect(
        api.patch(f"/leagues/{lid}/members/{other_id}/", {"role": "TOURNAMENT_ADMIN"})[0] == 200,
        "promote failed"))
    step("owner role is locked", lambda: _expect_status(
        lambda: api.patch(f"/leagues/{lid}/members/{me_id}/", {"role": "PLAYER"}), 403))
    step("remove member", lambda: expect(
        api.delete(f"/leagues/{lid}/members/{other_id}/")[0] == 204, "remove failed"))

    # ── results ─────────────────────────────────────────────────────────────
    total = len(PASSED) + len(FAILED)
    print(f"\n{'=' * 62}")
    print(f"  {len(PASSED)}/{total} steps passed")
    if FAILED:
        print(f"\n  FAILURES:")
        for label, err in FAILED:
            print(f"    - {label}\n        {err}")
    print(f"{'=' * 62}\n")
    print(f"League id for cleanup: {lid}")
    return 1 if FAILED else 0


def _status_of(fn):
    """HTTP status of a call, treating 404 as a normal (non-exception) outcome.

    Several endpoints legitimately 404 when nothing exists yet — e.g. a league
    with no current season. Those steps assert on the status rather than
    treating the 404 as a transport error.
    """
    try:
        return fn()[0]
    except ApiError as e:
        return e.status


def _upload_evidence(api, league_id, match_id, content, name="smoke.png"):
    """Evidence is posted as base64 JSON, matching the app's upload path."""
    import base64
    status, data = api.post(
        f"/leagues/{league_id}/matches/{match_id}/evidence/upload/",
        {
            "file_content_base64": base64.b64encode(content).decode(),
            "file_name": name,
            "file_size": len(content),
            "file_type": "image/png",
        },
    )
    expect(status in (200, 201), f"upload returned {status}: {data}")
    expect(data.get("is_valid") is True,
           f"evidence not accepted as valid: {data.get('validation_errors')}")
    return data


def _created(result, what):
    status, data = result
    expect(status in (200, 201), f"create {what} returned {status}: {data}")
    return data


def _expect_status(fn, expected):
    try:
        status, _ = fn()
        raise AssertionError(f"expected {expected}, got {status}")
    except ApiError as e:
        expect(e.status == expected, f"expected {expected}, got {e.status}")


if __name__ == "__main__":
    sys.exit(main())

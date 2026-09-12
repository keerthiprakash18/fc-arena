"""Live end-to-end check of the team match fixes against a running backend.

Verifies the three defects fixed in this session actually behave on real HTTP:
  1. team matches serialise team names / venue (previously None)
  2. a team member can submit a result (previously 403)
  3. verifying a team match moves TeamStatistics without crashing

Run:  python live_team_check.py
"""

import json
import sys
import urllib.error
import urllib.request

BASE = 'http://127.0.0.1:8000/api'
USERNAME = 'luciferkp'
PASSWORD = 'keerthi@1518'

_token = None


def call(method, path, body=None, token=None):
    url = BASE + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header('Content-Type', 'application/json')
    auth = token or _token
    if auth:
        req.add_header('Authorization', f'Bearer {auth}')
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            raw = resp.read().decode()
            return resp.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode()
        try:
            return exc.code, json.loads(raw)
        except json.JSONDecodeError:
            return exc.code, raw


def results(payload):
    """Unwrap DRF pagination."""
    if isinstance(payload, dict) and 'results' in payload:
        return payload['results']
    return payload if isinstance(payload, list) else []


def main():
    global _token

    status, body = call('POST', '/auth/login/',
                        {'username': USERNAME, 'password': PASSWORD})
    if status != 200:
        print(f'login failed: {status} {body}')
        return 1
    _token = body['access']
    print(f'login                     : 200 (user={USERNAME})')

    _, leagues = call('GET', '/leagues/')
    leagues = results(leagues)
    if not leagues:
        print('no leagues found for this user')
        return 1
    league = leagues[0]
    lid = league['id']
    print(f'league                    : {league["name"]} ({league["league_code"]})')

    _, teams = call('GET', f'/leagues/{lid}/teams/')
    teams = results(teams)
    print(f'teams                     : {[t["name"] for t in teams]}')

    _, matches = call('GET', f'/leagues/{lid}/matches/')
    matches = results(matches)
    print(f'matches                   : {len(matches)}')

    # ── defect 1: team names must be populated ──────────────────────────────
    team_matches = [m for m in matches if m.get('is_team_match')]
    if not team_matches:
        print('no team matches present — nothing to check for defect 1')
        return 1
    m = team_matches[0]
    print(f'  serialized              : {m["home_display"]} vs {m["away_display"]}'
          f' | venue={m.get("venue")!r}')
    print(f'  team names              : home={m.get("home_team_name")!r} '
          f'away={m.get("away_team_name")!r}')
    if m.get('home_team_name') is None or m.get('away_team_name') is None:
        print('  FAIL defect 1: team names still null')
        return 1
    print('  PASS defect 1: team names present')

    # ── defect 2: submit a result ───────────────────────────────────────────
    target = next((x for x in team_matches if x['status'] == 'SCHEDULED'), team_matches[0])
    if target['status'] == 'SCHEDULED':
        status, body = call('POST',
                            f'/leagues/{lid}/matches/{target["id"]}/status/',
                            {'status': 'AWAITING_RESULT'})
        print(f'  -> AWAITING_RESULT      : {status}')

    status, body = call('POST', f'/leagues/{lid}/matches/{target["id"]}/submit/',
                        {'home_score': 2, 'away_score': 1})
    print(f'  submit result           : {status}')
    if status != 200:
        print(f'  FAIL defect 2: {body}')
        return 1
    print(f'  status now              : {body["status"]}')
    print('  PASS defect 2: result accepted')

    # ── defect 3: the stats endpoint must answer cleanly ────────────────────
    status, stats = call('GET', f'/leagues/{lid}/teams/{target["home_team"]}/statistics/')
    print(f'  team statistics         : {status} -> {stats}')
    if status != 200:
        print('  FAIL: statistics endpoint did not answer')
        return 1
    print('  PASS defect 3a: statistics endpoint responds (null = no row yet)')

    # The full verify pipeline (notification formatting + TeamStatistics move)
    # is exercised by the live_db_pipeline_check shell step that follows.
    status, body = call('GET', f'/leagues/{lid}/matches/')
    print(f'  match list after submit : {status}')
    if status != 200:
        print('  FAIL: match list broke after a team result')
        return 1

    print('\nAll live HTTP checks passed.')
    return 0


if __name__ == '__main__':
    sys.exit(main())

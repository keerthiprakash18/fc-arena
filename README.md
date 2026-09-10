# FC ARENA — Esports Management Platform

A full-stack esports league & tournament management platform: Flutter frontend + Django REST backend, with AI-assisted match result verification.

## Features

**Leagues & members**
- Create/join leagues via invite code; member roles (owner, admin, tournament-admin, player)
- League admin panel: edit league, promote/demote members, remove members, copy invite code
- Categories: rating-band categories with player assignment/removal (admin only)

**Matches & verification**
- Schedule head-to-head matches between league members
- Match timeline events (goals, cards, assists, saves, penalties)
- Evidence upload + list per match, full-screen evidence viewer
- Verification pipeline: awaiting result → evidence submitted → AI processing → admin review → verified/rejected (OCR provider runs locally — `OCR_PROVIDER=local`)
- Disputes, match stats (shots, possession, cards…), head-to-head records

**Tournaments**
- Knockout (with byes for odd field + automatic round advancement) and league round-robin formats
- Registration flow + auto fixture generation (admin)
- Visual bracket view with status colors; rounds section
- Auto-advance on verification: winners promoted, losers eliminated, tournament completion

**Tracking & reports**
- Standings + leaderboards (rating/wins/goals/win-rate/goal-diff/matches) with season filter
- Player profile stats: record, form, streaks, match history (season filter)
- Season management with join/leave; awards; league overview dashboard

**App experience**
- Splash → first-run onboarding → login
- Notifications with unread badge, mark-read/mark-all-read, swipe-to-delete
- Match schedule filter (all/upcoming/live/completed), settings with prefs
- Installable PWA (web) with branded icons

## Tech stack

| Layer | Tech |
|---|---|
| Frontend | Flutter 3.47 / Dart 3.13, Provider, `shared_preferences`, web/PWA |
| Backend | Django 5 + DRF, PostgreSQL |
| Verification | Local OCR provider (`OCR_PROVIDER=local`; no AI credits consumed) |

## Project layout

```
backend/
  config/            Django settings + root urls
  accounts/          auth (JWT via djangorestframework-simplejwt)
  leagues/           leagues, members, invite codes, league admin
  matches/           match CRUD, events, stats, status transitions
  verification/      evidence → AI/OCR → review → VERIFIED pipeline
  evidence/          evidence file storage + list
  tournaments/       tournaments, brackets, rounds, auto fixtures
  leaderboards/      per-category leaderboards, regenerate
  statistics/        player/league stats, standings, rebuild
  seasons/           seasons + season members
  categories/        rating categories + player assignment
  notifications/     user notifications, preferences
  disputes/          match disputes
  awards/            awards
  headtohead/        head-to-head comparisons
backend/
  lib/
    config/          ApiClient (tokens, HTTP)
    models/          data models (match, tournament, category, season…)
    providers/       AuthProvider
    screens/         all screens
    services/        ApiService (typed API methods)
    main.dart        app entry (SplashScreen → Onboarding/Login)
```

## Setup

### Backend

```bash
cd backend
python -m venv venv
venv/Scripts/activate
pip install -r requirements.txt
# configure .env (DB creds, DRF_SECRET_KEY, OCR_PROVIDER=local)
venv/Scripts/python manage.py migrate
venv/Scripts/python manage.py createsuperuser
venv/Scripts/python manage.py runserver 0.0.0.0:8000
```

API root: `http://localhost:8000/api/` — auth via JSON Web Tokens at `POST /auth/login/`.

### Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api
# or mobile emulator (10.0.2.2 reaches host localhost):
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

Web release build (also produces the installable PWA):

```bash
flutter build web --dart-define=API_BASE_URL=http://localhost:8000/api
```

## QA

```bash
cd backend && venv/Scripts/python manage.py check   # backend sanity
cd frontend && flutter analyze                       # 0 issues expected
cd frontend && flutter test                          # widget tests (splash → onboarding, skip-onboarding)
cd frontend && flutter build web --dart-define=API_BASE_URL=http://localhost:8000/api
```

## Demo users

| User | Password | Role |
|---|---|---|
| `luciferkp` | `keerthi@1518` | league 1 owner (invite code `FC-7SXVJS`) |
| `player2` | `testpass123` | league member |

## Key design notes

- **Verification is credit-free**: OCR runs locally, so no AI API credits are consumed.
- **Match → season is indirect**: `Match → tournament → season` (no season FK on matches).
- **Leaderboards/statistics/standings** accept `?season_id=`; omit = all-time.
- **Fixtures**: `POST /leagues/<league_id>/tournaments/<tournament_id>/fixtures/` generates round matches (knockout with byes or round-robin); verifying round matches auto-creates the next round.
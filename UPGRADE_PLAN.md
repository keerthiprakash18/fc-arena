# FC ARENA → FCFC Upgrade Plan

Status: **STEP 1–3 complete (audit done). STEP 4 = this document. STEP 5+ = implementation.**

---

## 1. Audit summary — what actually exists

### Stack

| Layer | Reality |
|---|---|
| Backend | Django 6.1.1 + DRF 3.18 + PostgreSQL 18, **17 apps**, JWT (`simplejwt`) |
| API style | `generics.*` / `APIView` with explicit `path()` routes. **No ViewSets, no routers, no `@action`.** |
| Frontend | Flutter 3.47.2, `provider` (only `AuthProvider`), **36 screens**, imperative `Navigator.push`, no named routes |
| Charts | **none** — no `fl_chart`, no `syncfusion` |
| Animation | essentially none — only `splash_screen.dart` + `AnimatedContainer` dots in onboarding |
| Image cache | **none** — no `cached_network_image` |
| Signals | **none** — all statistics are service-driven |

### 🔴 The decisive finding

**There is no `Team` model anywhere.** Exhaustive search for `Team`/`Squad`/`Roster`/`Club` returns zero matches.

Matches are **User vs User**:

```python
# backend/matches/models.py
home_user = models.ForeignKey(settings.AUTH_USER_MODEL, related_name='home_matches')
away_user = models.ForeignKey(settings.AUTH_USER_MODEL, related_name='away_matches')
```

…and **every** downstream model is keyed on `user`, not team:
`PlayerLeagueStatistics`, `LeagueStanding`, `PlayerLeagueRating`, `RatingHistory`,
`Leaderboard`, `LeagueRecord`, `Award`, `MatchEvent.player`, `TournamentParticipant.user`.

Your spec is overwhelmingly team-centric. This is the one change that touches everything.

### ✅ What already exists and must be REUSED, not rebuilt

| Spec § | Already implemented | Where |
|---|---|---|
| §5 Fixture generator | `generate_league_fixtures` (round-robin), `generate_knockout_fixtures` (seeded, byes) | `tournaments/services.py` |
| §10 Knockout progression | `advance_tournament_after_verification` — auto-promotes winners, eliminates losers, builds next round | `tournaments/services.py:145` |
| §9 Groups | `TournamentGroup`, `TournamentGroupMember` | `tournaments/models.py:112` |
| §7 Result → stats automation | `statistics.services.process_verified_match` — idempotent, transactional; updates stats + Elo + standings | `statistics/services.py` |
| §8 Screenshot upload | Base64 JSON upload + SHA-256 dedupe + validation (png/jpeg/webp ≤10MB) | `evidence/` |
| §16 Leaderboards | 7 categories, auto-recalculated after verification | `leaderboards/services.py` |
| §17 Awards | 12 award types incl. `GOLDEN_BOOT`, `TOURNAMENT_MVP` | `awards/models.py` |
| §19 Live/verification | OCR pipeline w/ confidence threshold 0.85, admin review queue | `verification/services.py` |
| §20 Form | `current_win_streak`, `longest_unbeaten`, `win_streak` on stats | `statistics/models.py` |
| §2 Tournament statuses | 11-state machine + `VALID_TRANSITIONS` + transition log | `tournaments/models.py:38` |
| §26 Organizer controls | `IsLeagueAdmin` / `IsLeagueOwner` permission classes | `leagues/permissions.py` |

### 🔴 Confirmed dead code / stubs (safe to build into)

- `records/services.py` — **empty**, `LeagueRecord` is never populated (read-only endpoint only)
- `matches/services.py`, `evidence/services.py` — empty stubs
- `awards` — no service; awards are manual-only despite an `AUTO` choice existing
- `AuthGate` in `main.dart:71-108` — defined but **unused**
- `frontend/assets/images/` — declared in pubspec but **empty**

---

## 2. Architecture decision: additive Team layer

Your rules decide this: *"Reuse existing models where possible"* + *"Do not remove existing functionality."*

**Therefore: add Teams as a parallel layer. Do NOT migrate away from User-based matches.**

```
BEFORE:  Match.home_user ──┐
                            ├──► statistics / standings / ratings / leaderboards (keyed on User)
         Match.away_user ──┘

AFTER:   Match.home_user  ──────► existing User-keyed pipeline   (UNCHANGED — keeps working)
         Match.away_team  ──────► new Team-keyed pipeline        (ADDED)
```

Concretely: `home_team` / `away_team` are **nullable** FKs on `Match`. A match is either
user-based (legacy) or team-based (new). Existing code paths are untouched; new
`team_statistics` service runs alongside. **Zero regression risk to the working app.**

---

## 3. Gap analysis — spec vs reality

| Spec § | Status | Work required |
|---|---|---|
| §1 Vision / §23 UI | 🟡 Partial | Premium dark theme exists; needs match cards, charts, polish |
| §2 Tournament creation | 🟡 Partial | Model has 11 fields; **missing** logo, banner, game, registration start, min teams, prize text, rules |
| §3 Team management | 🔴 **Missing** | Whole `teams` app |
| §4 Player management | 🟡 Partial | `User` has `game_uid`, `game_in_game_name`, `profile_photo`; **missing** position, country, social links |
| §5 Fixture generator | 🟡 Partial | Exists for users; needs team support + scheduling params (interval, match days, venue) |
| §6 Fixture visual cards | 🔴 Missing | New widget + animations |
| §7 Result system | 🟢 Exists | Extend for team-based |
| §8 Screenshot upload | 🟢 Exists | Add replace/delete + fullscreen modal |
| §9 Group stage | 🟡 Models only | No API/UI to create groups or auto-assign |
| §10 Knockout bracket | 🟡 Logic only | `bracket_view.dart` is a **flat list**, not a tree |
| §11 Tournament dashboard | 🔴 Missing | New aggregate endpoint + screen |
| §12 Statistics center | 🟡 Partial | Endpoints exist; no dedicated screen |
| §13 Animated statistics | 🔴 Missing | Needs chart package + counter/progress widgets |
| §14 Player performance cards | 🔴 Missing | New widget |
| §15 Team comparison graphics | 🔴 Missing | New widget |
| §16 Leaderboards | 🟢 Exists | Add photos/logos |
| §17 Awards | 🟡 Exists | Trophy cards + auto-computation |
| §18 Tournament progress | 🔴 Missing | Compute from data |
| §19 Live match | 🔴 Missing | New screen + goal animation |
| §20 Form system | 🟡 Data only | Form is computed; no visual widget |
| §21 Search & filter | 🔴 Missing | Global search endpoint + UI |
| §22 Media system | 🔴 Missing | Image pipeline, fallbacks, caching |
| §24 Navigation | 🟡 Partial | 5 tabs; spec wants 12 sections |
| §25 Profile | 🟡 Partial | Exists; needs organizer view |
| §27 Validation/security | 🟡 Partial | Permission classes exist; needs team-level checks |
| §28 Database | 🟢 Good | Reuse; add Team + extend Tournament |
| §29 Performance | 🟡 Partial | Needs pagination, debounce, `select_related` |
| §30 Responsive | 🟡 Partial | Mobile-first; needs tablet/desktop layouts |
| §31 Animation rules | 🔴 Missing | Needs reduced-motion support |
| §32 Empty/error states | 🟢 Exists | `EmptyState`, `ErrorRetry` widgets already built |
| §34 No fake data | 🟢 Enforced | Empty DB by design |

---

## 4. Phased implementation

Ordered by dependency — each phase is independently shippable and leaves the app working.

### Phase 1 — Team foundation `[backend]`
- New app `teams`: `Team`, `TeamMember`
  - `Team`: league, name, short_name, slug, logo, banner, description, captain, manager, game, social_links (JSON), is_active
  - `TeamMember`: team, user, role (CAPTAIN/PLAYER/SUBSTITUTE), jersey_number, joined_at
- Serializers + CRUD views + permissions (reuse `IsLeagueAdmin`)
- Routes under `/api/leagues/<id>/teams/`
- Validation: unique team name per league, no duplicate member, captain must be a member

### Phase 2 — Tournament + player field extensions `[backend]`
- `Tournament`: add `logo`, `banner`, `game`, `registration_start`, `min_teams`, `rules`, `prize_description`, `is_team_based`
- `User`: add `position`, `country`, `social_links`
- `Match`: add nullable `home_team`, `away_team`
- `TournamentParticipant`: add nullable `team`

### Phase 3 — Team fixtures & standings `[backend]`
- `generate_team_fixtures()` + scheduling params (interval, match days, start time, venue)
- `teams/services.py`: team statistics computed from VERIFIED matches (mirrors the existing user pipeline)
- Group assignment API (manual + auto snake-seed)
- `records` service (currently empty — fill it)

### Phase 4 — Frontend core `[frontend]`
- `models/team.dart`, `ApiService` team methods
- Teams list + Team profile screen (logo, banner, W/D/L, GF/GA/GD, points, form)
- Fixture match cards + knockout bracket tree
- Navigation restructure

### Phase 5 — Animation & analytics `[frontend]`
- Add `fl_chart` + `cached_network_image`
- Animated counters, progress rings, bar comparisons, form graphs
- Player performance card, team comparison
- Respect `MediaQuery.disableAnimations` (reduced motion)

### Phase 6 — Search, dashboard, live, polish
- Global search endpoint + UI
- Tournament dashboard aggregates
- Live match screen + goal animation
- Responsive breakpoints, pagination, debounce

---

## 5. Constraints honoured

- ✅ No rebuild from scratch — all existing apps/screens/auth/APIs preserved
- ✅ No fake/demo data — every number derives from real DB rows; empty states already exist
- ✅ Additive migrations only — existing tables keep their data
- ✅ Reuse `GlassCard`, `StatusBadge`, `EmptyState`, `ErrorRetry`, `FCColors`, `FCGradients`

## 6. Risks

| Risk | Mitigation |
|---|---|
| Team layer bloats `Match` with two participant systems | Nullable FKs; a match asserts exactly one pair is set |
| Duplicated stat logic (user + team) | Share the aggregation helper; team service mirrors user service structure |
| Chart package adds weight | `fl_chart` is pure Dart, no native deps |
| No image cache → slow logo grids | Add `cached_network_image` in Phase 5 |

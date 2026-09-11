# FC ARENA — Run Guide

How to get the **backend API**, the **web app**, and the **mobile app** running.
For cloud deployment see `DEPLOYMENT.md`.

---

## 0. Prerequisites

| Tool | Version used | Check |
|---|---|---|
| Python | 3.13 | `python --version` |
| Flutter | 3.47+ | `flutter --version` |
| Java JDK | 17 | `java -version` |
| PostgreSQL | 14+ | running on `localhost:5432` |

The backend virtualenv (`backend/venv`) and `backend/.env` already exist in this repo.

> Run the backend test suite at least once? Grant the DB user the right to
> create a test database: `psql -U postgres -c "ALTER ROLE fc_arena_user CREATEDB;"`

---

## 1. Backend API (required for both apps)

```bash
cd backend
venv/Scripts/python.exe manage.py migrate          # first run / after model changes
venv/Scripts/python.exe manage.py runserver 0.0.0.0:8000
```

`0.0.0.0` matters — it lets your phone reach the API over Wi-Fi, not just the
local machine.

Verify:

```bash
curl http://localhost:8000/api/health/
# {"status": "ok", "database": true, "version": "1.0.0"}
```

| URL | What it is |
|---|---|
| `http://localhost:8000/api/` | API root + route listing |
| `http://localhost:8000/api/health/` | liveness + database probe |
| `http://localhost:8000/admin/` | Django admin |

**Demo accounts**

| Username | Password | Role |
|---|---|---|
| `luciferkp` | `keerthi@1518` | league owner (invite code `FC-7SXVJS`) |
| `player2` | `testpass123` | league member |

---

## 2. Web app

### Build

```bash
cd frontend
flutter build web --release --dart-define=API_BASE_URL=http://localhost:8000/api
```

### Serve

```bash
python serve_web.py          # http://localhost:8080
python serve_web.py 9000     # custom port
```

`serve_web.py` exists because Flutter web needs `.wasm` / `.mjs` served with the
correct Content-Type — a plain `python -m http.server` can hand back the wrong
type and give you a blank page.

The build in `frontend/build/web` is also an installable **PWA**: open it in
Chrome and use *Install app*.

### Hot-reload during development

```bash
cd frontend
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api
```

---

## 3. Mobile app

### Option A — emulator (fastest)

```bash
cd frontend
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

`10.0.2.2` is how the Android emulator reaches the host machine's `localhost`.

### Option B — real phone over Wi-Fi

1. Put the phone on the **same Wi-Fi** as this machine.
2. Find this machine's LAN IP (`ipconfig`) — currently **192.168.1.5**.
3. Allow the port through the firewall (once, PowerShell as admin):
   ```powershell
   New-NetFirewallRule -DisplayName "FC ARENA API" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow
   ```
4. Build and install:
   ```bash
   cd frontend
   flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.5:8000/api
   ```
   APK lands at `frontend/build/app/outputs/flutter-apk/app-release.apk`.
   Install it, or:
   ```bash
   flutter install
   ```

> The LAN IP can change when you reconnect to Wi-Fi. You do **not** need to
> rebuild — change it in the app (see below).

### Option C — against a deployed backend

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://your-api.example.com/api
```

---

## 4. Changing the API server at runtime (no rebuild)

The server URL is not baked in. If the app can't reach the backend:

- **Login screen** → the ⚙ network icon (top right) → edit the URL → **TEST** → **SAVE**.
- **Settings → SERVER → API Server** → same dialog, plus **RESET** to go back to the build-time default.

Handy values:

| Situation | URL |
|---|---|
| Web app on this machine | `http://localhost:8000/api` |
| Android emulator | `http://10.0.2.2:8000/api` |
| Real phone on Wi-Fi | `http://192.168.1.5:8000/api` |
| Deployed backend | `https://your-api.example.com/api` |

The choice is stored on the device, so one APK works everywhere.

---

## 5. Release builds

### Android signing

`frontend/android/app/build.gradle.kts` picks up `frontend/android/key.properties`
automatically. Without that file, release builds are signed with the **debug**
key — fine for installing and testing, **not** accepted by Google Play.

To create a real upload key:

```powershell
keytool -genkeypair -v -keystore "C:\Users\micha\Videos\FC-ARENA\android-upload-key.jks" `
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload `
  -storepass <PASSWORD> -keypass <PASSWORD> -dname "CN=FC Arena,O=YourName,C=IN"
```

Then create `frontend/android/key.properties`:

```
storePassword=<PASSWORD>
keyPassword=<PASSWORD>
keyAlias=upload
storeFile=C:/Users/micha/Videos/FC-ARENA/android-upload-key.jks
```

Back both up offline — losing them means you can never update the app again.

### Play Store bundle

```bash
cd frontend
flutter build appbundle --release --dart-define=API_BASE_URL=https://your-api.example.com/api
# -> frontend/build/app/outputs/bundle/release/app-release.aab
```

---

## 6. Health check before shipping

```bash
cd backend   && venv/Scripts/python.exe manage.py check        # config sanity
cd backend   && venv/Scripts/python.exe manage.py test tests   # 90 API tests, ~3s
cd frontend  && flutter analyze                                # expect: No issues found
cd frontend  && flutter test                                   # splash / onboarding widget tests
```

> **`flutter test` needs a proxy bypass in this environment.** `HTTP_PROXY` is
> set here and intercepts the local `flutter_tester` socket, producing
> `Invalid WebSocket upgrade request`. Run it as:
> ```bash
> NO_PROXY=localhost,127.0.0.1 flutter test
> ```

### Backend tests

`backend/tests/` holds ~90 API tests covering auth, leagues, matches (including
the full status-transition state machine), categories, tournaments, dashboard,
leaderboards and notifications. They run against a throwaway Postgres database.

The database user needs permission to create it — grant once:

```bash
psql -U postgres -c "ALTER ROLE fc_arena_user CREATEDB;"
```

Without that you'll see `permission denied to create database`.

---

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Blank white page on web | wrong MIME type for `.wasm`/`.mjs` | serve with `python serve_web.py` |
| Web app loads, login spins forever | API URL wrong or CORS blocked | set the URL via ⚙ on the login screen; check `CORS_ALLOWED_ORIGINS` |
| Phone can't reach the API | not on same Wi-Fi, or firewall | same network + `New-NetFirewallRule` above |
| `Cannot reach http://...` in the app | backend not running | start `runserver 0.0.0.0:8000` |
| `502` / `degraded` from `/api/health/` | Postgres down | start PostgreSQL, check `backend/.env` |
| Evidence uploads vanish after redeploy | no persistent disk on free hosting | configure S3/R2 (`DEPLOYMENT.md` §5) |
| `flutter test` fails with `Invalid WebSocket upgrade request` | an `HTTP_PROXY` env var is intercepting the local `flutter_tester` socket | run `NO_PROXY=localhost,127.0.0.1 flutter test` |

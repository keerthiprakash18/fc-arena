# FC ARENA — Production Deployment Guide

Everything is pre-configured in this repo. You only need free-tier cloud accounts and ~1–2 hours for your first launch.

> Stack: **Django REST backend** (Render) + **PostgreSQL** (Render) + **Flutter Android app** (Google Play) + optional **web PWA** (Render/Cloudflare Pages).

---

## 0. What you need (accounts — all free except Play)

| # | Service | Purpose | Cost |
|---|---------|---------|------|
| 1 | GitHub account | host the code (Render pulls from here) | free |
| 2 | Render account | run the Django API + Postgres + web PWA | free tier |
| 3 | Google account | Play Console | **$25 one-time** |
| 4 | Java (JDK 17) | create the signing key | free |
| 5 | (optional) Cloudflare R2 / AWS S3 | permanent evidence file storage | free tier / pay-as-you-go |

---

## 1. Push the code to GitHub (first time)

```bash
cd "C:\Users\micha\Videos\FC-ARENA"
git init
git add .
git commit -m "FC ARENA initial"
git branch -M main
git remote add origin https://github.com/<YOUR_GITHUB_USERNAME>/fc-arena.git
git push -u origin main
```

**Never commit `backend/.env`** (it is gitignored). It contains your DB password and Django secret.

---

## 2. Deploy the backend API (Render)

1. Go to https://dashboard.render.com → **New → Blueprint**.
2. Paste your GitHub repo URL → Render detects `infra/render.yaml`.
3. It creates two resources:
   - **fcarena-pg** (Postgres, free)
   - **fcarena-api** (Django, free web service)
4. In the web service → **Environment** → add secrets:
   - `SECRET_KEY` — generate:
     ```bash
     python -c "import secrets; print(secrets.token_urlsafe(50))"
     ```
   - `CORS_ALLOWED_ORIGINS` — your future web URL + anything you host the web app at, e.g. `https://fc-arena.onrender.com`
   - `DATABASE_URL` is auto-filled from the Postgres instance (the included `render_migrate.sh` splits it into the vars Django reads and runs `migrate` + `collectstatic` on every deploy).
5. Click **Apply / Deploy**. When finished you get:
   ```
   https://fcarena-api.onrender.com/
   API base URL:  https://fcarena-api.onrender.com/api/
   ```
6. Create the admin superuser. Pick **one** of these:

   **a) Automatic (recommended)** — add these env vars to the web service, then redeploy:
   ```
   DJANGO_SUPERUSER_USERNAME=luciferkp
   DJANGO_SUPERUSER_PASSWORD=<a strong password>
   DJANGO_SUPERUSER_EMAIL=you@example.com
   ```
   `render_migrate.sh` creates the account on deploy and leaves it alone on later deploys.

   **b) Manual** — Render dashboard → fcarena-api → **Shell**:
   ```bash
   python manage.py createsuperuser
   ```

   > There is deliberately **no default password**. An earlier version of this
   > script created `admin` / `Admin@123` automatically, which is a public
   > open door on any deployed URL — do not reintroduce it.

Verify: open `https://fcarena-api.onrender.com/api/` and `/admin/` — both should load.
`/api/health/` should return `{"status": "ok", "database": true, ...}`.

> **OCR note:** the free local OCR (`winrt`) is Windows-only. On Render/Linux the pipeline skips OCR and falls back to **manual admin verification** — results are still verified, just not auto-OCR'd. Paid OCR (`EXPLABS_*` keys) can be added later without code changes.

> **Evidence files on free Render:** the free plan has no persistent disk — uploaded evidence will vanish on redeploy. For durable files set up S3/R2 (section 5) and flip `USE_S3=True`.

---

## 3. Test the whole app (Play “internal testing”)

Before going public, you can test the real .apk on your own phone via Play Console's **Internal testing** track.

### 3.1 Set the production API URL
The app reads the API base at build time:

```bash
cd "C:\Users\micha\Videos\FC-ARENA\frontend"
flutter build apk --release --dart-define=API_BASE_URL=https://fcarena-api.onrender.com/api/
```

(or use an emulator if you prefer: `flutter run --dart-define=API_BASE_URL=https://fcarena-api.onrender.com/api/`)

### 3.2 Create your signing key (ONE TIME — keep it safe forever)
```powershell
keytool -genkeypair -v -keystore "C:\Users\micha\Videos\FC-ARENA\android-upload-key.jks" `
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload `
  -storepass <YOUR_PASSWORD> -keypass <YOUR_PASSWORD> -dname "CN=FC Arena,O=YourName,C=IN"
```
Back up `android-upload-key.jks` + the two passwords in a safe place. If you lose them you can never update the app.

### 3.3 Point the build at the key
Create `frontend/android/key.properties` (gitignored):
```
storePassword=<YOUR_PASSWORD>
keyPassword=<YOUR_PASSWORD>
keyAlias=upload
storeFile=C:/Users/micha/Videos/FC-ARENA/android-upload-key.jks
```
Then uncomment/set the release signing block in `frontend/android/app/build.gradle.kts`:
```kotlin
signingConfigs {
    create("release") {
        val props = java.util.Properties().apply { load(file("../key.properties").inputStream()) }
        storeFile = file(props["storeFile"] as String)
        storePassword = props["storePassword"] as String
        keyAlias = props["keyAlias"] as String
        keyPassword = props["keyPassword"] as String
    }
}
buildTypes {
    release { signingConfig = signingConfigs.getByName("release") }
}
```

### 3.4 Upload to Internal testing
1. https://play.google.com/console → **Create app** (app name: *FC ARENA*).
2. **Setup → App signing → opt into Play App Signing** → upload your upload key cert (or let Play manage experimental signing).
3. **Setup → Internal testing → Create new release**
   - Build the bundle: `flutter build appbundle --release --dart-define=API_BASE_URL=https://fcarena-api.onrender.com/api/`
   - Upload `frontend/build/app/outputs/bundle/release/app-release.aab`
   - Note: `applicationId` is already set to `com.fcarena.app` and the label to “FC ARENA”.
4. Add your Google email to the tester list → **Save & publish**.
5. Install from the provided opt-in link on your phone → **test every screen** (login, matches, evidence upload, tournaments, notifications).

---

## 4. Going public on Play Store

1. **Setup → App content**: privacy policy (host a simple page), ads declaration (none), target audience, etc.
2. Fill app listing: description, screenshots (phone), feature graphic (1024×500), app icon, category *Sports*.
3. **Release → Production → Create release** → upload the same `.aab`.
4. **Pricing & distribution → Countries**: select everywhere.
5. Review checklist; then **Publish** — first review usually takes a few hours to a few days.
6. Every future update: bump `version:` in `frontend/pubspec.yaml`, rebuild the `.aab`, upload to the same release track.

---

## 5. (Recommended before public) Durable evidence storage — Cloudflare R2

1. R2 (dashboard.cloudflare.com → R2) → create bucket `fcarena-media`.
2. API tokens: R2 → Manage R2 Access Keys → create key/secret.
3. Add to Render env (fcarena-api):
   ```
   USE_S3=True
   S3_ACCESS_KEY_ID=<access key>
   S3_SECRET_ACCESS_KEY=<secret>
   S3_BUCKET_NAME=fcarena-media
   S3_REGION_NAME=auto
   S3_ENDPOINT_URL=https://<accountid>.r2.cloudflarestorage.com
   ```
4. Redeploy — from now on evidence files are durable and served directly from R2.

---

## 6. (Optional) Host the web PWA too

Render **Static Site** pointed at `frontend` with:
- Build command: `flutter build web --dart-define=API_BASE_URL=https://fcarena-api.onrender.com/api/`
- Publish directory: `build/web`
Set `CORS_ALLOWED_ORIGINS` on the API to that site's URL. Features the mobile app (invite codes, notifications, evidence) — works identically on the web.

---

## 7. Post-launch hygiene checklist

- [ ] `DEBUG=False` everywhere (Render env already sets it; `manage.py check --deploy` passes)
- [ ] Allowed hosts set (no wildcard if avoidable)
- [ ] `SECRET_KEY` is long/random and stored only in Render secrets
- [ ] DB backups: Render *snapshots* (manual) — enable daily
- [ ] App signing key backed up offline
- [ ] Smoke-test after every deploy: login → matches → evidence → standings

---

## Layout of the deploy files added

```
backend/requirements.txt      pinned deps (gunicorn, whitenoise, storages)
backend/Procfile              web + release commands (Railway/Heroku-style hosts)
backend/render_migrate.sh     DB-URL → env split + migrate + collectstatic
backend/.env.example          documentation of every env var
infra/render.yaml             Render blueprint (Postgres + Django web)
.gitignore                    secrets/artifacts never committed
```
#!/usr/bin/env bash
# Converts DATABASE_URL into the DATABASE_* vars Django expects,
# then runs migrations + static collection. Runs automatically on deploy.
set -e

if [ -n "$DATABASE_URL" ]; then
  eval "$(python -c "
import os, urllib.parse
u = urllib.parse.urlparse(os.environ['DATABASE_URL'])
print(f'export DATABASE_USER=\"{u.username}\"')
print(f'export DATABASE_PASSWORD=\"{u.password}\"')
print(f'export DATABASE_HOST=\"{u.hostname}\"')
print(f'export DATABASE_PORT=\"{u.port or 5432}\"')
print(f'export DATABASE_NAME=\"{u.path.lstrip(\"/\").split(\"?\")[0]}\"')
")"
  # Write .env so gunicorn workers (a separate process) can read the DB config.
  python -c "
import os, urllib.parse
u = urllib.parse.urlparse(os.environ['DATABASE_URL'])
with open('.env', 'w') as f:
    f.write(f'DATABASE_USER={u.username}\n')
    f.write(f'DATABASE_PASSWORD={u.password}\n')
    f.write(f'DATABASE_HOST={u.hostname}\n')
    f.write(f'DATABASE_PORT={u.port or 5432}\n')
    f.write(f'DATABASE_NAME={u.path.lstrip(\"/\").split(\"?\")[0]}\n')
print('Wrote .env with DB credentials')
"
fi

export DEBUG=0
python manage.py migrate --noinput
python manage.py collectstatic --noinput --clear

# Create an initial superuser only when credentials are supplied via env vars.
# We deliberately do NOT bake in a default password: a predictable admin login
# on a public URL is an open door. Set DJANGO_SUPERUSER_USERNAME and
# DJANGO_SUPERUSER_PASSWORD in your host's environment to have one created.
if [ -n "$DJANGO_SUPERUSER_USERNAME" ] && [ -n "$DJANGO_SUPERUSER_PASSWORD" ]; then
  python manage.py createsuperuser --noinput 2>/dev/null \
    && echo "Created superuser: $DJANGO_SUPERUSER_USERNAME" \
    || echo "Superuser '$DJANGO_SUPERUSER_USERNAME' already exists - leaving it untouched."
else
  echo "No DJANGO_SUPERUSER_USERNAME/PASSWORD set - skipping superuser creation."
  echo "To create one later: Render dashboard -> Shell ->"
  echo "  python manage.py createsuperuser"
fi

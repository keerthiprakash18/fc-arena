#!/usr/bin/env bash
# Converts Render's DATABASE_URL into the DATABASE_* vars Django expects,
# then runs migrations + static collection. Runs automatically on deploy.
set -e

if [ -n "$DATABASE_URL" ]; then
  # postgres://USER:PASS@HOST:PORT/NAME
  url="${DATABASE_URL#*://}"
  export DATABASE_USER="${url%%:*}"
  rest="${url#*:}"
  export DATABASE_PASSWORD="${rest%%@*}"
  hostport="${rest#*@}"
  export DATABASE_HOST="${hostport%%:*}"
  rest2="${hostport#*:}"
  export DATABASE_PORT="${rest2%%/*}"
  export DATABASE_NAME="${rest2#*/}"
  export DATABASE_NAME="${DATABASE_NAME%%\?*}"
fi

export DEBUG=0
python manage.py migrate --noinput
python manage.py collectstatic --noinput --clear
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
fi

export DEBUG=0
python manage.py migrate --noinput
python manage.py collectstatic --noinput --clear

# Create default superuser if none exists
python -c "
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()
from accounts.models import User
if not User.objects.filter(is_superuser=True).exists():
    User.objects.create_superuser('admin', 'admin@fcarena.com', 'Admin@123')
    print('Created superuser: admin / Admin@123')
else:
    print('Superuser already exists')
"

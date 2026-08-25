# Homelab PostgreSQL Mode

Use this only when intentionally switching the homelab API application database from Supabase PROD to the local PostgreSQL container.

Supabase still remains responsible for:

- Auth
- access tokens
- Storage

Homelab PostgreSQL becomes responsible for Prisma application tables.

## 1. Confirm PostgreSQL Is Running

```bash
cd /srv/apps/OSK-Manager/deploy
docker compose --profile postgres up -d postgres
docker compose --profile postgres ps
```

## 2. Export Public Data From Current Supabase PROD

Run this before changing `/srv/apps/OSK-Manager/BE/.env`, while `DATABASE_URL` still points to Supabase PROD:

```bash
cd /srv/apps/OSK-Manager/deploy
PROD_DB_URL="$(grep '^DATABASE_URL=' ../BE/.env | cut -d= -f2-)"
docker run --rm -v "$(pwd):/work" postgres:17 pg_dump \
  --dbname "$PROD_DB_URL" \
  --schema public \
  --data-only \
  --no-owner \
  --no-acl \
  --disable-triggers \
  --exclude-table-data 'public._prisma_migrations' \
  --file /work/prod-public-data.sql
```

If the local homelab PostgreSQL container is Postgres 16 and the dump comes
from Supabase Postgres 17, remove unsupported Postgres 17-only settings before
import:

```bash
grep -v "transaction_timeout" prod-public-data.sql > prod-public-data.pg16.sql
```

## 3. Apply Prisma Migrations To Homelab PostgreSQL

```bash
cd /srv/apps/OSK-Manager/deploy
set -a
. ./.env
set +a
HOMELAB_HOST_DB_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@127.0.0.1:${POSTGRES_PORT:-5432}/${POSTGRES_DB}"

cd /srv/apps/OSK-Manager/BE
DATABASE_URL="$HOMELAB_HOST_DB_URL" npx prisma migrate deploy
```

## 4. Import Public Data Into Homelab PostgreSQL

```bash
cd /srv/apps/OSK-Manager/deploy
set -a
. ./.env
set +a

{
  echo "SET session_replication_role = replica;"
  cat prod-public-data.pg16.sql
  echo "SET session_replication_role = DEFAULT;"
} | docker compose --profile postgres exec -T postgres \
  psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1
```

## 5. Switch API DATABASE_URL

Edit `/srv/apps/OSK-Manager/BE/.env`:

```env
DATABASE_URL=postgresql://osk_manager:<POSTGRES_PASSWORD>@postgres:5432/osk_manager
```

Keep Supabase values for Auth and Storage:

```env
SUPABASE_URL=...
SUPABASE_SERVICE_ROLE_KEY=...
SUPABASE_ANON_KEY=...
SUPABASE_JWT_SECRET=...
```

## 6. Restart API And Frontend

```bash
cd /srv/apps/OSK-Manager/deploy
docker compose --profile postgres up -d --build
docker compose --profile postgres ps
docker compose logs api --tail=80
```

## 7. Verify

```bash
curl http://localhost:3001/test
```

Then verify in the browser:

- login works
- dashboard loads
- users/courses/lessons/payments data is visible
- avatar and vehicle images still load from Supabase Storage

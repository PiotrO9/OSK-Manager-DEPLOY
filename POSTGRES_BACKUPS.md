# PostgreSQL Backups

This document describes the homelab PostgreSQL backup setup for OSK Manager.

## Location

Backups are stored on the homelab host:

```bash
/srv/backups/osk-manager/postgres
```

The backup script is stored in the deploy repository:

```bash
/srv/apps/OSK-Manager/deploy/scripts/backup-postgres.sh
```

## Schedule

Backups run every day at 03:00 through the `piotrek` user's crontab:

```cron
0 3 * * * PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin /srv/apps/OSK-Manager/deploy/scripts/backup-postgres.sh >> /srv/backups/osk-manager/postgres/backup.log 2>&1
```

Backup logs are written to:

```bash
/srv/backups/osk-manager/postgres/backup.log
```

## Retention

The backup script keeps timestamped `.dump` files and removes backups older
than 14 days.

Backups use PostgreSQL custom format:

```bash
pg_dump -Fc
```

## Run A Manual Backup

```bash
cd /srv/apps/OSK-Manager/deploy
./scripts/backup-postgres.sh
```

Check created backups:

```bash
ls -lh /srv/backups/osk-manager/postgres
```

Check backup logs:

```bash
tail -n 50 /srv/backups/osk-manager/postgres/backup.log
```

## Restore Test

Do not restore directly into the main database during a test. Restore into a
separate database first.

Create a test database:

```bash
cd /srv/apps/OSK-Manager/deploy
docker compose --profile postgres exec postgres \
  createdb -U osk_manager osk_manager_restore_test
```

Restore a selected backup:

```bash
docker compose --profile postgres exec -T postgres \
  pg_restore -U osk_manager -d osk_manager_restore_test --clean --if-exists \
  < /srv/backups/osk-manager/postgres/<backup-file>.dump
```

Verify restored data:

```bash
docker compose --profile postgres exec postgres \
  psql -U osk_manager -d osk_manager_restore_test \
  -c "select 'users' as table_name, count(*) from users union all select 'driving_schools', count(*) from driving_schools union all select 'courses', count(*) from courses union all select 'lessons', count(*) from lessons union all select 'vehicles', count(*) from vehicles;"
```

Remove the test database after verification:

```bash
docker compose --profile postgres exec postgres \
  dropdb -U osk_manager osk_manager_restore_test
```

Confirm cleanup:

```bash
docker compose --profile postgres exec postgres \
  psql -U osk_manager -d osk_manager \
  -c "select datname from pg_database where datname = 'osk_manager_restore_test';"
```

Expected result:

```text
0 rows
```

## Emergency Restore To Main Database

Use this only when intentionally replacing the current homelab database state
with a backup.

Stop the application containers first:

```bash
cd /srv/apps/OSK-Manager/deploy
docker compose --profile postgres stop api frontend
```

Restore the selected backup into the main database:

```bash
docker compose --profile postgres exec -T postgres \
  pg_restore -U osk_manager -d osk_manager --clean --if-exists \
  < /srv/backups/osk-manager/postgres/<backup-file>.dump
```

Start the application again:

```bash
docker compose --profile postgres up -d api frontend
```

Verify:

```bash
curl --fail --silent --show-error http://localhost:3001/health
curl --fail --silent --show-error http://localhost:3001/test
curl -i http://localhost:3000
```

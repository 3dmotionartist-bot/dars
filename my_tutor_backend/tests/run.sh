#!/usr/bin/env bash
# Recreates a scratch database, loads the Supabase stub + migrations + seed, runs the scenario test.
set -euo pipefail
DB=${DB:-dars_test}
HERE="$(cd "$(dirname "$0")/.." && pwd)"
dropdb --if-exists "$DB" && createdb "$DB"
psql -q -v ON_ERROR_STOP=1 -d "$DB" -c "do \$\$ begin if not exists (select from pg_roles where rolname='anon') then
  create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls; end if; end \$\$;"
sed '/^create role/d;/^grant anon, authenticated, service_role to authenticator/d' "$HERE/tests/supabase_stub.sql" | psql -q -v ON_ERROR_STOP=1 -d "$DB"
for f in "$HERE"/supabase/migrations/*.sql "$HERE/supabase/seed.sql"; do psql -q -v ON_ERROR_STOP=1 -d "$DB" -f "$f"; done
psql -v ON_ERROR_STOP=1 -d "$DB" -f "$HERE/tests/flows.sql"
psql -v ON_ERROR_STOP=1 -d "$DB" -f "$HERE/tests/week_fixes.sql"

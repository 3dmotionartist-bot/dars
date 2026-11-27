#!/usr/bin/env bash
# Recreates a scratch database, loads the Supabase stub + migrations + seed, runs the scenario test.
set -euo pipefail
PERF=0; [ "${1:-}" = "--perf" ] && PERF=1
DB=${DB:-dars_test}
HERE="$(cd "$(dirname "$0")/.." && pwd)"
dropdb --if-exists "$DB" && createdb "$DB"
psql -q -v ON_ERROR_STOP=1 -d "$DB" -c "do \$\$ begin if not exists (select from pg_roles where rolname='anon') then
  create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls; end if; end \$\$;"
sed '/^create role/d;/^grant anon, authenticated, service_role to authenticator/d' "$HERE/tests/supabase_stub.sql" | psql -q -v ON_ERROR_STOP=1 -d "$DB"
for f in "$HERE"/supabase/migrations/*.sql "$HERE/supabase/seed.sql"; do psql -q -v ON_ERROR_STOP=1 -d "$DB" -f "$f"; done
# The older test files were written before Round F: they book tutors that never saved working hours and pay out
# earnings at once. They run with those two rules relaxed; tests/round_f.sql switches them back and tests them.
psql -q -v ON_ERROR_STOP=1 -d "$DB" -c "update app_settings set value = 'true' where key = 'bookable_without_hours'; update app_settings set value = '0' where key = 'earnings_hold_hours';"
psql -v ON_ERROR_STOP=1 -d "$DB" -f "$HERE/tests/flows.sql"
psql -v ON_ERROR_STOP=1 -d "$DB" -f "$HERE/tests/week_fixes.sql"
psql -v ON_ERROR_STOP=1 -d "$DB" -f "$HERE/tests/retest_fixes.sql"
psql -v ON_ERROR_STOP=1 -d "$DB" -f "$HERE/tests/week2.sql"
psql -v ON_ERROR_STOP=1 -d "$DB" -f "$HERE/tests/week2_retest.sql"
psql -v ON_ERROR_STOP=1 -d "$DB" -f "$HERE/tests/capacity.sql"
psql -v ON_ERROR_STOP=1 -d "$DB" -f "$HERE/tests/round_b.sql"
psql -v ON_ERROR_STOP=1 -d "$DB" -f "$HERE/tests/round_d.sql"
psql -v ON_ERROR_STOP=1 -d "$DB" -f "$HERE/tests/round_e.sql"
psql -v ON_ERROR_STOP=1 -d "$DB" -f "$HERE/tests/round_f.sql"
psql -v ON_ERROR_STOP=1 -d "$DB" -f "$HERE/tests/round_h.sql"
psql -v ON_ERROR_STOP=1 -d "$DB" -f "$HERE/tests/round_g.sql"
psql -v ON_ERROR_STOP=1 -d "$DB" -f "$HERE/tests/round_g2.sql"
# Edge functions turn-credentials and push-notifications (fakes for Cloudflare / Firebase / Supabase; Node 22+)
if command -v node >/dev/null 2>&1 && node -e 'process.exit(Number(process.versions.node.split(".")[0]) < 22 ? 1 : 0)'; then
  node --experimental-strip-types --no-warnings "$HERE/tests/turn_credentials.test.mjs" \
    || { echo "FAIL: turn-credentials tests"; exit 1; }
  node --experimental-strip-types --no-warnings "$HERE/tests/push_notifications.test.mjs" \
    || { echo "FAIL: push-notifications tests"; exit 1; }
else
  echo "skip edge-function tests (Node 22+ not found)"
fi

# --perf: big copy (50,000 users, ~78,000 chats, ~1.9 M messages) and timings. Not part of the default run.
if [ "$PERF" = 1 ]; then
  P=${PERF_DB:-dars_perf}
  dropdb --if-exists "$P" && createdb "$P"
  sed '/^create role/d;/^grant anon, authenticated, service_role to authenticator/d' "$HERE/tests/supabase_stub.sql" | psql -q -v ON_ERROR_STOP=1 -d "$P"
  for f in "$HERE"/supabase/migrations/*.sql "$HERE/supabase/seed.sql"; do psql -q -v ON_ERROR_STOP=1 -d "$P" -f "$f"; done
  psql -v ON_ERROR_STOP=1 -d "$P" -f "$HERE/tests/perf_seed.sql"
  psql -v ON_ERROR_STOP=1 -d "$P" -f "$HERE/tests/perf_check.sql"
fi

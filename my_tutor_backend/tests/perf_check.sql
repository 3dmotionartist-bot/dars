-- Timings on the big copy (tests/run.sh --perf). Runs the same reads the app makes at start / on refresh,
-- signed in as a random student and as a tutor with ~40 chats. Target: under 30 ms in total.
\set QUIET on
\pset format unaligned
\pset tuples_only on

create or replace function pg_temp.app_refresh(p_user uuid, p_tutor boolean, p_new_app boolean, out chats_ms numeric, out messages_ms numeric,
  out notif_ms numeric, out wallet_ms numeric, out lessons_ms numeric, out total_ms numeric, out chats int)
language plpgsql as $$
declare t0 timestamptz; t timestamptz; ids uuid[]; i int;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  t0 := clock_timestamp(); t := t0;
  -- Backend.conversations()
  -- (new app versions also say "where I am student or tutor", so the two new indexes are used;
  --  old versions leave that to the read rule, which still works but reads the whole table)
  if p_new_app then
    select array_agg(id order by last_message_at desc) into ids
      from (select id, last_message_at from conversations where student_id = p_user or tutor_id = p_user
            order by last_message_at desc limit 100) c;
  else
    select array_agg(id order by last_message_at desc) into ids
      from (select id, last_message_at from conversations order by last_message_at desc limit 100) c;
  end if;
  chats := coalesce(array_length(ids, 1), 0);
  chats_ms := extract(epoch from clock_timestamp() - t) * 1000; t := clock_timestamp();
  -- Backend.messagesFor(): recent_messages, 20 chats at a time, 50 each
  i := 1;
  while i <= chats loop
    perform count(*) from recent_messages(ids[i:i + 19], 50);
    i := i + 20;
  end loop;
  messages_ms := extract(epoch from clock_timestamp() - t) * 1000; t := clock_timestamp();
  perform count(*) from (select * from notifications where user_id = p_user order by created_at desc limit 60) x;
  notif_ms := extract(epoch from clock_timestamp() - t) * 1000; t := clock_timestamp();
  perform count(*) from (select * from wallet_transactions where user_id = p_user order by created_at desc limit 100) x;
  perform balance from wallet_balances where user_id = p_user;
  wallet_ms := extract(epoch from clock_timestamp() - t) * 1000; t := clock_timestamp();
  if p_tutor then
    perform count(*) from (select * from lessons where tutor_id = p_user order by starts_at limit 500) x;
  else
    perform count(*) from (select * from lessons where student_id = p_user order by starts_at limit 500) x;
  end if;
  lessons_ms := extract(epoch from clock_timestamp() - t) * 1000;
  total_ms := extract(epoch from clock_timestamp() - t0) * 1000;
  execute 'reset role';
end $$;

create temp table perf_users as
  (select id, false as tutor from profiles where role = 'student' and email like 'perf%' order by random() limit 30)
  union all
  (select c.tutor_id, true from conversations c group by c.tutor_id order by abs(count(*) - 40), random() limit 30);

-- warm-up pass (first read of each page from disk), then the measured pass
select count(*) from perf_users u, lateral pg_temp.app_refresh(u.id, u.tutor, true) r \g /dev/null
create temp table perf_runs as
  select 'new app' as app, u.tutor, r.* from perf_users u, lateral pg_temp.app_refresh(u.id, u.tutor, true) r
  union all
  select 'old app', u.tutor, r.* from perf_users u, lateral pg_temp.app_refresh(u.id, u.tutor, false) r;

\echo 'app     | who      | users | chats | chat list | messages | notifications | wallet | lessons | TOTAL median | TOTAL p90 | TOTAL max  (ms)'
select format('%-7s | %-8s | %5s | %5s | %9s | %8s | %13s | %6s | %7s | %12s | %9s | %s',
  app, case when tutor then 'tutor' else 'student' end, count(*), round(avg(chats)),
  round(percentile_cont(0.5) within group (order by chats_ms)::numeric, 2),
  round(percentile_cont(0.5) within group (order by messages_ms)::numeric, 2),
  round(percentile_cont(0.5) within group (order by notif_ms)::numeric, 2),
  round(percentile_cont(0.5) within group (order by wallet_ms)::numeric, 2),
  round(percentile_cont(0.5) within group (order by lessons_ms)::numeric, 2),
  round(percentile_cont(0.5) within group (order by total_ms)::numeric, 2),
  round(percentile_cont(0.9) within group (order by total_ms)::numeric, 2),
  round(max(total_ms), 2))
from perf_runs group by app, tutor order by app, tutor;

select app || case when max(total_ms) < 30 then ': ok   every refresh under 30 ms'
            else ': WARN slowest refresh ' || round(max(total_ms), 1) || ' ms (target 30 ms)' end from perf_runs group by app order by app;

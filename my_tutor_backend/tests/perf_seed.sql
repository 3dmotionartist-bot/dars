-- Big copy for timing (tests/run.sh --perf). NOT part of the default run, never run on the live project.
-- 50,000 users (2,000 approved tutors), ~78,000 chats (~39 per tutor), ~1.9 M messages,
-- 250,000 notifications, 100,000 lessons, 100,000 wallet entries.
-- All triggers are off while loading (session_replication_role = replica), so profiles are inserted directly.
\set QUIET on
\timing off
set session_replication_role = replica;
set synchronous_commit = off;

create temp table pu (n int primary key, id uuid not null, tutor boolean not null);
insert into pu select g, gen_random_uuid(), g <= 2000 from generate_series(1, 50000) g;

insert into auth.users (id, email, raw_user_meta_data)
  select id, 'perf' || n || '@example.test', jsonb_build_object('role', case when tutor then 'tutor' else 'student' end) from pu;
insert into profiles (id, role, full_name, email, status)
  select id, case when tutor then 'tutor' else 'student' end::user_role, 'Perf user ' || n, 'perf' || n || '@example.test', 'active' from pu;
insert into tutor_profiles (user_id, headline, verification, verified_at, hourly_price)
  select id, 'Perf tutor ' || n, 'approved', now(), 5 + (n % 20) from pu where tutor;

-- chats: student k gets 1–2 tutors (78,000 in total), spread so each tutor has ~39
create temp table pc as
  select distinct on (s.id, t.id) gen_random_uuid() as id, s.id as student_id, t.id as tutor_id,
         now() - (random() * interval '90 days') as last_message_at
  from generate_series(1, 78000) g
  join pu s on s.n = 2001 + (g % 48000)
  join pu t on t.n = 1 + ((g * 7919 + (g / 48000) * 997) % 2000);
insert into conversations (id, student_id, tutor_id, last_message_at, created_at)
  select id, student_id, tutor_id, last_message_at, last_message_at - interval '30 days' from pc;

-- ~24 messages per chat (~1.9 M), alternating sender, the last one at last_message_at
insert into messages (conversation_id, sender_id, kind, body, read_at, created_at)
  select c.id, case when i % 2 = 0 then c.student_id else c.tutor_id end, 'text',
         'perf message ' || i, c.last_message_at, c.last_message_at - (i * interval '17 minutes')
  from pc c, generate_series(0, 23) i;

insert into notifications (user_id, title, body, created_at)
  select id, 'Perf', 'notification ' || i, now() - (i * interval '3 hours') from pu, generate_series(1, 5) i;

insert into lessons (student_id, tutor_id, starts_at, duration_min, status, price, created_at)
  select student_id, tutor_id, last_message_at + interval '2 days', 60, 'confirmed'::lesson_status, 10, last_message_at
  from (select * from pc order by random() limit 100000) x
  union all
  select student_id, tutor_id, last_message_at + interval '9 days', 60, 'delivered'::lesson_status, 10, last_message_at
  from (select * from pc order by random() limit 22000) y;

insert into wallet_transactions (user_id, amount, kind, note, created_at)
  select id, 5, 'adjustment', 'perf', now() - (i * interval '1 day') from pu, generate_series(1, 2) i where not tutor;

set session_replication_role = origin;
vacuum analyze;
select format('seeded: %s users, %s tutors, %s chats, %s messages, %s notifications, %s lessons',
  (select count(*) from profiles), (select count(*) from tutor_profiles where verification = 'approved'),
  (select count(*) from conversations), (select count(*) from messages),
  (select count(*) from notifications), (select count(*) from lessons));

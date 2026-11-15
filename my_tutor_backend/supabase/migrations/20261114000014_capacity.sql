-- Stage 3, Round A — capacity and cost.
-- Safe to run once (and harmless if run again). Deletes no data.
--
-- A1. Read rules ran auth.uid() / is_admin() / is_active_user() once PER ROW, and the chat list
--     had no index for tutors. Here every rule's call is wrapped as "(select …)" so Postgres runs it
--     once per query, and the missing indexes are added. Who may see or change what is unchanged.
-- A3. Two settings for the call video cap, readable by signed-in users.

-- ── 1. Indexes the rules and the app's lists need ───────────────────────────
create index if not exists conversations_student_recent on conversations (student_id, last_message_at desc);
create index if not exists conversations_tutor_recent   on conversations (tutor_id, last_message_at desc);
create index if not exists payments_user_recent        on payments (user_id, created_at desc);
create index if not exists payouts_tutor_recent        on payouts (tutor_id, created_at desc);
create index if not exists reviews_student             on reviews (student_id);
create index if not exists reports_reporter            on reports (reporter_id);
create index if not exists live_responses_tutor        on live_responses (tutor_id);
create index if not exists availability_slots_tutor    on availability_slots (tutor_id);
create index if not exists wallet_tx_user_recent       on wallet_transactions (user_id, created_at desc);

-- ── 2. The chat rules, written out as the brief asks ────────────────────────
alter policy party_read on conversations
  using ((student_id = (select auth.uid()) or tutor_id = (select auth.uid())) and (select is_active_user()));
alter policy admin_all on conversations
  using ((select is_admin())) with check ((select is_admin()));

-- ── 3. Every other rule (public and storage): wrap the same calls ───────────
-- Only calls without arguments are wrapped (they give the same answer for every row).
-- A call already written as "( SELECT x() AS x)" is left alone, so running this twice changes nothing.
create or replace function pg_temp.dars_wrap(t text) returns text language sql immutable as $f$
  select case when t is null then null else
    regexp_replace(
      regexp_replace(t,
        '(?<!SELECT )\mauth\.(uid|role|jwt)\(\)', '(select auth.\1())', 'g'),
      '(?<!SELECT )(?<![.\w])(public\.)?(is_admin|is_active_user|is_approved_tutor)\(\)', '(select public.\2())', 'g')
  end
$f$;

do $$
declare r record; q text; c text; n int := 0;
begin
  for r in select schemaname, tablename, policyname, qual, with_check from pg_policies
           where schemaname in ('public', 'storage')
  loop
    q := pg_temp.dars_wrap(r.qual);
    c := pg_temp.dars_wrap(r.with_check);
    if q is distinct from r.qual or c is distinct from r.with_check then
      execute format('alter policy %I on %I.%I', r.policyname, r.schemaname, r.tablename)
        || case when r.qual is not null then format(' using (%s)', q) else '' end
        || case when r.with_check is not null then format(' with check (%s)', c) else '' end;
      n := n + 1;
    end if;
  end loop;
  raise notice 'rules rewritten: %', n;

  -- Stop (and undo everything above) if any rule still calls one of these per row.
  if exists (select 1 from pg_policies where schemaname in ('public', 'storage')
             and (pg_temp.dars_wrap(qual) is distinct from qual or pg_temp.dars_wrap(with_check) is distinct from with_check)) then
    raise exception 'a rule still calls auth.uid()/is_admin()/is_active_user()/is_approved_tutor() per row';
  end if;
end $$;

-- ── 4. A3: call video cap (owner can change without a new build) ────────────
insert into app_settings (key, value) values
  ('call_video_kbps', '600'),
  ('call_video_height', '480')
on conflict (key) do nothing;

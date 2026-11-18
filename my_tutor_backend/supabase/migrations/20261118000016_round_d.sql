-- Round D — calls and notifications.
-- Safe to run once (and harmless if run again). Deletes no data. Old app versions keep working
-- (they simply don't save a device token, so they keep the in-app ringing they have today).
--
-- D1. Push notifications: device tokens (one row per phone), the person's on/off switches (messages / calls /
--     reminders), lesson reminders 24 h, 1 h and 10 min before, and "missed call" notices.
--     The push-notifications edge function sends them; it is called by two database webhooks the owner
--     creates in the dashboard (messages INSERT, notifications INSERT) with the x-dars-hook header.
-- D4. server_now(): the server's clock, so the app decides "is this call still ringing?" without trusting
--     the phone's clock.

-- ── D1. Device tokens ─────────────────────────────────────────────────────────────────────────────────
create table if not exists device_tokens (
  token      text primary key check (char_length(token) between 20 and 4096),
  user_id    uuid not null references profiles(id) on delete cascade,
  platform   text not null default 'android' check (platform in ('android', 'web', 'ios')),
  lang       text not null default 'ar' check (lang in ('ar', 'en')),   -- language of the app on that phone
  updated_at timestamptz not null default now()
);
create index if not exists device_tokens_user on device_tokens (user_id, updated_at desc);
alter table device_tokens enable row level security;
revoke all on device_tokens from public, anon, authenticated;
grant select on device_tokens to authenticated;
drop policy if exists device_tokens_own on device_tokens;
create policy device_tokens_own on device_tokens for select to authenticated using (user_id = (select auth.uid()));

-- Saves this phone's token for the signed-in person. A phone that was used by another account before
-- moves to this account (so the old account stops getting this phone's notifications). At most 10 phones.
create or replace function save_device_token(p_token text, p_platform text default 'android', p_lang text default 'ar')
returns void language plpgsql volatile security definer set search_path = public as $$
declare
  v_uid   uuid := auth.uid();
  v_token text := trim(coalesce(p_token, ''));
begin
  if v_uid is null or not is_active_user() then raise exception 'Not allowed' using errcode = '42501'; end if;
  if v_token !~ '^[A-Za-z0-9:_.-]+$' or char_length(v_token) not between 20 and 4096 then raise exception 'Bad device token' using errcode = '22023'; end if;
  perform pg_advisory_xact_lock(hashtext('device_tokens:' || v_uid::text));
  insert into device_tokens (token, user_id, platform, lang, updated_at)
  values (v_token, v_uid,
          case when p_platform in ('android', 'web', 'ios') then p_platform else 'android' end,
          case when p_lang = 'en' then 'en' else 'ar' end, now())
  on conflict (token) do update
    set user_id = excluded.user_id, platform = excluded.platform, lang = excluded.lang, updated_at = now();
  delete from device_tokens d
  where d.user_id = v_uid
    and d.token in (select t.token from device_tokens t where t.user_id = v_uid order by t.updated_at desc offset 10);
end $$;
revoke execute on function save_device_token(text, text, text) from public, anon;
grant execute on function save_device_token(text, text, text) to authenticated;

-- Sign-out: this phone stops getting this account's notifications.
create or replace function remove_device_token(p_token text) returns void
language sql volatile security definer set search_path = public as $$
  delete from device_tokens where token = p_token and user_id = auth.uid();
$$;
revoke execute on function remove_device_token(text) from public, anon;
grant execute on function remove_device_token(text) to authenticated;

-- ── D1. On / off switches ─────────────────────────────────────────────────────────────────────────────
create table if not exists notification_prefs (
  user_id    uuid primary key references profiles(id) on delete cascade,
  messages   boolean not null default true,
  calls      boolean not null default true,
  reminders  boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table notification_prefs enable row level security;
revoke all on notification_prefs from public, anon, authenticated;

create or replace function my_notification_prefs() returns table (messages boolean, calls boolean, reminders boolean)
language sql stable security definer set search_path = public as $$
  select coalesce(p.messages, true), coalesce(p.calls, true), coalesce(p.reminders, true)
  from (select auth.uid() as uid) u
  left join notification_prefs p on p.user_id = u.uid
  where u.uid is not null;
$$;
revoke execute on function my_notification_prefs() from public, anon;
grant execute on function my_notification_prefs() to authenticated;

-- null = leave that switch as it is.
create or replace function set_notification_prefs(p_messages boolean default null, p_calls boolean default null,
                                                  p_reminders boolean default null)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  if auth.uid() is null or not is_active_user() then raise exception 'Not allowed' using errcode = '42501'; end if;
  insert into notification_prefs (user_id, messages, calls, reminders, updated_at)
  values (auth.uid(), coalesce(p_messages, true), coalesce(p_calls, true), coalesce(p_reminders, true), now())
  on conflict (user_id) do update
    set messages  = coalesce(p_messages,  notification_prefs.messages),
        calls     = coalesce(p_calls,     notification_prefs.calls),
        reminders = coalesce(p_reminders, notification_prefs.reminders),
        updated_at = now();
end $$;
revoke execute on function set_notification_prefs(boolean, boolean, boolean) from public, anon;
grant execute on function set_notification_prefs(boolean, boolean, boolean) to authenticated;

-- ── D1. Lesson reminders: 24 hours, 1 hour and 10 minutes before (each once) ──────────────────────────
-- Run every minute by pg_cron. A lesson booked less than a day ahead gets no "24 hours" reminder (and one
-- booked less than an hour ahead no "1 hour" one), so nobody gets three reminders right after booking.
create table if not exists lesson_reminders (
  lesson_id uuid not null references lessons(id) on delete cascade,
  kind      text not null check (kind in ('24h', '1h', '10m')),
  sent_at   timestamptz not null default now(),
  primary key (lesson_id, kind)
);
alter table lesson_reminders enable row level security;
revoke all on lesson_reminders from public, anon, authenticated;
create index if not exists lessons_confirmed_start on lessons (starts_at) where status = 'confirmed';

create or replace function send_lesson_reminders() returns int
language plpgsql volatile security definer set search_path = public as $$
declare
  r     record;
  n     int := 0;
  v_in  text;
begin
  for r in
    insert into lesson_reminders (lesson_id, kind)
    select l.id, k.kind
    from lessons l
    cross join lateral (values
      ('24h', l.starts_at <= now() + interval '24 hours' and l.starts_at > now() + interval '1 hour'
              and l.created_at <= l.starts_at - interval '23 hours'),
      ('1h',  l.starts_at <= now() + interval '1 hour' and l.starts_at > now() + interval '10 minutes'
              and l.created_at <= l.starts_at - interval '50 minutes'),
      ('10m', l.starts_at <= now() + interval '10 minutes')
    ) k(kind, due)
    where l.status = 'confirmed' and l.starts_at > now() and l.starts_at <= now() + interval '24 hours' and k.due
    on conflict do nothing
    returning lesson_id, kind
  loop
    v_in := case r.kind when '24h' then '24 hours' when '1h' then '1 hour' else '10 minutes' end;
    perform push_notification(p, 'Lesson reminder', 'Lesson #' || l.number || ' starts in ' || v_in || '.',
                              jsonb_build_object('type', 'reminder', 'lesson_id', l.id, 'kind', r.kind, 'starts_at', l.starts_at))
    from lessons l, unnest(array[l.student_id, l.tutor_id]) p
    where l.id = r.lesson_id;
    n := n + 1;
  end loop;
  return n;
end $$;
revoke execute on function send_lesson_reminders() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('dars-lesson-reminders', '* * * * *', 'select public.send_lesson_reminders()');
  end if;
end $$;

-- ── D1 / D4. Missed call ──────────────────────────────────────────────────────────────────────────────
-- The caller's app calls this when a call it started ended before the other person joined (no answer, or
-- the caller hung up first). The other person gets one "missed call" notice — which also stops the ringing
-- on a phone whose app is closed. Only for the caller's own call from the last 10 minutes, once per call.
create or replace function call_not_answered(p_room text) returns boolean
language plpgsql volatile security definer set search_path = public as $$
declare
  v_uid  uuid := auth.uid();
  m      record;
  v_to   uuid;
  v_name text;
begin
  if v_uid is null or not is_active_user() then return false; end if;
  if coalesce(p_room, '') !~ '^[a-hjkmnp-z]{5}(-[a-hjkmnp-z]{5}){3}$' then return false; end if;
  select x.body, x.conversation_id, c.student_id, c.tutor_id into m
  from messages x join conversations c on c.id = x.conversation_id
  where x.kind = 'call' and split_part(x.body, ':', 2) = p_room and x.sender_id = v_uid
    and split_part(x.body, ':', 1) in ('voice', 'video') and x.created_at > now() - interval '10 minutes'
  order by x.created_at desc
  limit 1;
  if not found then return false; end if;
  v_to := case when m.student_id = v_uid then m.tutor_id else m.student_id end;
  perform pg_advisory_xact_lock(hashtext('missed_call:' || p_room));
  if exists (select 1 from notifications n
             where n.user_id = v_to and n.created_at > now() - interval '1 day'
               and n.data ->> 'type' = 'missed_call' and n.data ->> 'room' = p_room) then
    return false;
  end if;
  select full_name into v_name from profiles where id = v_uid;
  perform push_notification(v_to, 'Missed call', coalesce(nullif(trim(v_name), ''), 'Dars'),
    jsonb_build_object('type', 'missed_call', 'room', p_room, 'conversation_id', m.conversation_id,
                       'video', split_part(m.body, ':', 1) = 'video', 'from', v_uid));
  return true;
end $$;
revoke execute on function call_not_answered(text) from public, anon;
grant execute on function call_not_answered(text) to authenticated;

-- ── D4. The server's clock ────────────────────────────────────────────────────────────────────────────
create or replace function server_now() returns timestamptz language sql stable as $$ select now() $$;
grant execute on function server_now() to anon, authenticated;

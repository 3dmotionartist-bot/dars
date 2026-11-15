-- Stage 3, Round B — calls off the paid paths, tutor list in pages.
-- Safe to run once (and harmless if run again). Deletes no data.
--
-- B2. Relay passwords (turn-credentials edge function): guests on the browser call page only for a recent
--     Dars call room, at most 10 an hour per address and 20 an hour per room; signed-in users only when their
--     account is active, at most 30 an hour. The function calls turn_guest_allowed() / turn_user_allowed()
--     with the service key; nobody else can.
-- B3. search_tutors(): the tutor list 30 at a time, searched, filtered and sorted on the server,
--     with Arabic letter variants treated alike (أ/إ/آ/ا, ة/ه, ى/ي, no tashkeel).

-- ── B3. Tutor search ────────────────────────────────────────────────────────
-- Arabic-insensitive form of a text: no tashkeel or tatweel, أ/إ/آ/ٱ → ا, ى → ي, ة → ه, lower case.
create or replace function dars_norm(t text) returns text
language sql immutable parallel safe set search_path = public as $$
  select lower(translate(regexp_replace(coalesce(t, ''), '[ً-ٰٟـ]', '', 'g'), 'أإآٱىة', 'اااايه'))
$$;

create or replace function search_tutors(
  p_query     text    default null,
  p_subject   text    default null,
  p_gender    text    default null,   -- 'm' | 'f' | null / 'all'
  p_price_min numeric default null,
  p_price_max numeric default null,
  p_sort      text    default 'best', -- 'best' | 'price' | 'rating'
  p_limit     int     default 30,     -- at most 50
  p_offset    int     default 0,
  p_available boolean default false,  -- online now only
  p_instant   boolean default false,  -- instant booking only
  p_packages  boolean default false,  -- offers packages only
  p_in_person boolean default false,  -- teaches in person only
  p_interests text[]  default null    -- the student's subjects: lifts matching tutors in 'best'
) returns table (
  id uuid, full_name text, avatar_url text, gender text, country text, headline text,
  years_experience int, languages jsonb, teaches_online boolean, teaches_in_person boolean,
  hourly_price numeric, currency text, max_package_discount int, instant_booking boolean,
  cancel_hours int, available_now boolean, rating_avg numeric, rating_count int, hours_taught numeric,
  video_url text, is_new boolean, subject_ids text[], students bigint,
  total_count bigint                  -- how many tutors match in all (for "N results")
)
-- Security definer: reads tutor_profiles / profiles directly (like the public_tutors view does) so that only
-- the 30 tutors of the page get their subject list and student count worked out — about 100× less work
-- than going through the view with 2,000 tutors. Same tutors (approved + active) and same public columns.
language sql stable security definer set search_path = public as $$
  with q as (
    select nullif(replace(replace(replace(dars_norm(trim(p_query)), '\', '\\'), '%', '\%'), '_', '\_'), '') as q
  ), m as (
    select t.user_id, p.full_name, p.avatar_url, p.gender, p.country, t.headline, t.years_experience, t.languages,
           t.teaches_online, t.teaches_in_person, t.hourly_price, t.currency, t.max_package_discount, t.instant_booking,
           t.cancel_hours, t.available_now and (t.dnd_until is null or t.dnd_until < now()) as available_now,
           t.rating_avg, t.rating_count, round(t.minutes_taught::numeric / 60.0) as hours_taught, t.video_url,
           t.verified_at > now() - interval '30 days' as is_new
    from tutor_profiles t
    join profiles p on p.id = t.user_id
    cross join q
    where t.verification = 'approved' and p.status = 'active'
      and (p_subject is null or p_subject = ''
           or exists (select 1 from tutor_subjects s where s.tutor_id = t.user_id and s.subject_id = p_subject))
      and (p_gender is null or p_gender in ('', 'all') or p.gender = p_gender)
      and (p_price_min is null or t.hourly_price >= p_price_min)
      and (p_price_max is null or t.hourly_price <= p_price_max)
      and (not coalesce(p_available, false) or (t.available_now and (t.dnd_until is null or t.dnd_until < now())))
      and (not coalesce(p_instant, false) or t.instant_booking)
      and (not coalesce(p_packages, false) or coalesce(t.max_package_discount, 0) > 0)
      and (not coalesce(p_in_person, false) or t.teaches_in_person)
      and (q.q is null or dars_norm(concat_ws(' ', p.full_name, t.headline,
            (select string_agg(s.name_ar || ' ' || s.name_en, ' ') from tutor_subjects ts join subjects s on s.id = ts.subject_id
              where ts.tutor_id = t.user_id))) like '%' || q.q || '%')
  ), r as (
    select m.*, count(*) over () as total_count,
           row_number() over (order by
             case when p_sort = 'price' then m.hourly_price end asc nulls last,
             case when p_sort = 'rating' then m.rating_avg end desc nulls last,
             case when p_sort = 'rating' then m.rating_count end desc nulls last,
             case when coalesce(p_sort, 'best') not in ('price', 'rating') then
               coalesce(m.rating_avg, 0) * 6 + case when m.available_now then 4 else 0 end
               + 8 * (select count(*) from tutor_subjects s where s.tutor_id = m.user_id and s.subject_id = any (coalesce(p_interests, '{}')))
             end desc nulls last,
             m.rating_count desc nulls last,
             m.user_id) as n            -- same order every time, so pages never repeat or skip
    from m
  )
  select r.user_id, r.full_name, r.avatar_url, r.gender, r.country, r.headline, r.years_experience, r.languages,
         r.teaches_online, r.teaches_in_person, r.hourly_price, r.currency, r.max_package_discount, r.instant_booking,
         r.cancel_hours, r.available_now, r.rating_avg, r.rating_count, r.hours_taught, r.video_url, r.is_new,
         coalesce((select array_agg(s.subject_id order by s.subject_id) from tutor_subjects s where s.tutor_id = r.user_id), '{}'),
         (select count(distinct l.student_id) from lessons l where l.tutor_id = r.user_id and l.status = 'delivered'),
         r.total_count
  from r
  where r.n > greatest(coalesce(p_offset, 0), 0)
    and r.n <= greatest(coalesce(p_offset, 0), 0) + least(greatest(coalesce(p_limit, 30), 1), 50)
  order by r.n
$$;
revoke execute on function search_tutors(text, text, text, numeric, numeric, text, int, int, boolean, boolean, boolean, boolean, text[]) from public;
grant execute on function search_tutors(text, text, text, numeric, numeric, text, int, int, boolean, boolean, boolean, boolean, text[]) to anon, authenticated;

-- Reviews now load when a tutor's profile opens, 20 at a time.
create index if not exists reviews_tutor_recent on reviews (tutor_id, created_at desc);

-- ── B2. Who may get relay passwords (checked by the turn-credentials function) ──
-- One log for both kinds of request; only the service key reaches it (no rules, no grants).
create table if not exists turn_requests (
  ip      text,                       -- guests: the caller's address
  room    text,                       -- guests: the call room
  user_id uuid,                       -- signed-in users
  at      timestamptz not null default now()
);
create index if not exists turn_requests_ip_at   on turn_requests (ip, at desc) where ip is not null;
create index if not exists turn_requests_room_at on turn_requests (room, at desc) where room is not null;
create index if not exists turn_requests_user_at on turn_requests (user_id, at desc) where user_id is not null;
alter table turn_requests enable row level security;
revoke all on turn_requests from public, anon, authenticated;

-- Call rooms are found through the chat message that started them ("video:<room>", "voice:…", "meet:…").
create index if not exists messages_call_room on messages ((split_part(body, ':', 2)), created_at) where kind = 'call';

-- Guests (browser call page): true = this address may get relay passwords for this room now (counted).
--   * the room must come from a recent call message: 24 hours for video / voice calls, 7 days for meeting links;
--   * at most 10 an hour per address, and 20 an hour per room (whatever the address).
create or replace function turn_guest_allowed(p_ip text, p_room text) returns boolean
language plpgsql volatile security definer set search_path = public as $$
declare
  v_ip text := left(coalesce(trim(p_ip), ''), 64);
begin
  if v_ip = '' or coalesce(p_room, '') !~ '^[a-hjkmnp-z]{5}(-[a-hjkmnp-z]{5}){3}$' then return false; end if;
  if not exists (
    select 1 from messages m
    where m.kind = 'call' and split_part(m.body, ':', 2) = p_room
      and m.created_at > now() - case when m.body like 'meet:%' then interval '7 days' else interval '24 hours' end
  ) then return false; end if;
  -- (tidy: entries older than a day are no longer needed)
  delete from turn_requests r where (r.ip = v_ip or r.room = p_room) and r.at < now() - interval '1 day';
  if (select count(*) from turn_requests r where r.ip = v_ip and r.at > now() - interval '1 hour') >= 10
     or (select count(*) from turn_requests r where r.room = p_room and r.at > now() - interval '1 hour') >= 20 then
    return false;
  end if;
  insert into turn_requests (ip, room) values (v_ip, p_room);
  return true;
end $$;
revoke execute on function turn_guest_allowed(text, text) from public, anon, authenticated;
grant execute on function turn_guest_allowed(text, text) to service_role;

-- Signed-in users: true = this account is active and asked fewer than 30 times in the last hour (counted).
create or replace function turn_user_allowed(p_user uuid) returns boolean
language plpgsql volatile security definer set search_path = public as $$
begin
  if p_user is null or not exists (select 1 from profiles where id = p_user and status = 'active') then return false; end if;
  delete from turn_requests r where r.user_id = p_user and r.at < now() - interval '1 day';
  if (select count(*) from turn_requests r where r.user_id = p_user and r.at > now() - interval '1 hour') >= 30 then
    return false;
  end if;
  insert into turn_requests (user_id) values (p_user);
  return true;
end $$;
revoke execute on function turn_user_allowed(uuid) from public, anon, authenticated;
grant execute on function turn_user_allowed(uuid) to service_role;

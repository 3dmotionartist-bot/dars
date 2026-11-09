-- =====================================================================
-- 1) Security monitor: phone numbers / contact details / contact requests in chats
--    The users are not warned. Numbers, emails and contact links are hidden from the other
--    person (blocked = true, as before) and every hit is flagged for the admin, who gets a
--    live alarm in the dashboard.
-- =====================================================================

-- What a chat text contains: [{"kind": "phone"|"email"|"link"|"contact_request", "matched": "..."}]
create or replace function contact_hits(p_body text) returns jsonb
language plpgsql immutable set search_path = public as $$
declare
  b text;
  lb text;
  hits jsonb := '[]';
  m text;
  d text;
  words int := 0;
  w text;
  nums text[] := array[
    'صفر','واحد','وحده','وحدة','اثنين','اثنان','إثنين','ثنين','تنين','اتنين','ثلاثة','ثلاثه','ثلاث','تلاتة','تلاته','تلات',
    'اربعة','أربعة','اربعه','أربعه','اربع','أربع','خمسة','خمسه','خمس','ستة','سته','ست','سبعة','سبعه','سبع',
    'ثمانية','ثمانيه','ثمنية','تمانية','تمانيه','ثمان','تمن','تسعة','تسعه','تسع',
    'zero','one','two','three','four','five','six','seven','eight','nine','oh'];
begin
  if p_body is null or btrim(p_body) = '' then return hits; end if;
  -- Arabic-Indic and Persian digits count as digits too
  b := translate(p_body, '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', '01234567890123456789');
  lb := lower(b);

  -- phone numbers: 8+ digits (or 7+ starting with 0 / +), spaces, dashes, dots or brackets allowed between them
  for m in select (regexp_matches(b, '\+?\d[\d\s\-\.\(\)/_]{5,}\d', 'g'))[1] loop
    d := regexp_replace(m, '\D', '', 'g');
    -- dates like 2026-11-09 or 09/11/2026 are not phone numbers
    continue when m ~ '^\s*\d{4}[-/.]\d{1,2}[-/.]\d{1,2}\s*$' or m ~ '^\s*\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}\s*$';
    if length(d) >= 8 or (length(d) >= 7 and (m ~ '^\s*(\+|0)')) then
      hits := hits || jsonb_build_array(jsonb_build_object('kind', 'phone', 'matched', btrim(m)));
      exit;
    end if;
  end loop;

  -- numbers written as words ("صفر تسعة ثلاثة ..." / "zero nine ...")
  if not exists (select 1 from jsonb_array_elements(hits) e where e->>'kind' = 'phone') then
    for w in select regexp_split_to_table(lb, '[\s,،\.\-_/|+]+') loop
      if w = any(nums) or (left(w, 1) = 'و' and substr(w, 2) = any(nums)) then
        words := words + 1;
      end if;
    end loop;
    if words >= 7 then
      hits := hits || jsonb_build_array(jsonb_build_object('kind', 'phone', 'matched', left(btrim(b), 120)));
    end if;
  end if;

  -- email addresses
  m := substring(lb from '([a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,})');
  if m is not null then
    hits := hits || jsonb_build_array(jsonb_build_object('kind', 'email', 'matched', m));
  end if;

  -- links to WhatsApp / Telegram / social profiles
  m := substring(lb from '((wa\.me|chat\.whatsapp\.com|api\.whatsapp\.com|t\.me/|telegram\.me|instagram\.com|snapchat\.com|facebook\.com|fb\.com|m\.me/)\S*)');
  if m is not null then
    hits := hits || jsonb_build_array(jsonb_build_object('kind', 'link', 'matched', m));
  end if;

  -- asking for / offering contact outside Dars (not hidden, only reported)
  m := substring(lb from '(whats\s?app|واتس|وتساب|واتساب|تلغرام|تليغرام|تيليجرام|تلجرام|telegram|viber|فايبر|signal|سيجنال|instagram|انستا|إنستا|انستغرام|سناب|snapchat|فيسبوك|فيس بوك|facebook|ماسنجر|messenger|رقمك|هذا رقمي|خذ رقمي|رقمي هو|على رقمي|رقم\s*(ال)?(موبايل|جوال|تلفون|تليفون|هاتف|واتس|التواصل)|موبايلك|جوالك|تلفونك|تليفونك|هاتفك|ايميلك|إيميلك|بريدك|your (phone|number|mobile|whatsapp|email)|my (phone|number|mobile|whatsapp|email)|phone number|call me|text me|contact me)');
  if m is not null and not exists (select 1 from jsonb_array_elements(hits)) then
    hits := hits || jsonb_build_array(jsonb_build_object('kind', 'contact_request', 'matched', m));
  end if;

  return hits;
end $$;

-- Before insert: hide numbers / emails / contact links from the other person (unchanged behaviour, better detection)
create or replace function filter_message() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.kind = 'text' and new.sender_id is not null then
    if exists (select 1 from jsonb_array_elements(contact_hits(new.body)) e where e->>'kind' in ('phone', 'email', 'link')) then
      new.blocked := true;
    end if;
  end if;
  update conversations set last_message_at = now() where id = new.conversation_id;
  return new;
end $$;

create table if not exists message_flags (
  id              bigint generated always as identity primary key,
  message_id      bigint not null references messages(id) on delete cascade,
  conversation_id uuid not null references conversations(id) on delete cascade,
  sender_id       uuid references profiles(id),
  kind            text not null check (kind in ('phone', 'email', 'link', 'contact_request')),
  matched         text not null default '',
  excerpt         text not null default '',
  status          text not null default 'new' check (status in ('new', 'reviewed', 'dismissed')),
  reviewed_by     uuid references profiles(id),
  reviewed_at     timestamptz,
  created_at      timestamptz not null default now()
);
create index if not exists message_flags_status_idx on message_flags (status, created_at desc);
create index if not exists message_flags_conv_idx on message_flags (conversation_id);
alter table message_flags enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'message_flags' and policyname = 'admin_all') then
    create policy admin_all on message_flags for all to authenticated using (is_admin()) with check (is_admin());
  end if;
end $$;

-- After insert: record every hit and tell the admins
create or replace function flag_message() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  e jsonb;
  n int := 0;
  who text;
  a uuid;
begin
  if new.kind <> 'text' or new.sender_id is null then return null; end if;
  for e in select * from jsonb_array_elements(contact_hits(new.body)) loop
    insert into message_flags (message_id, conversation_id, sender_id, kind, matched, excerpt)
    values (new.id, new.conversation_id, new.sender_id, e->>'kind', left(coalesce(e->>'matched', ''), 200), left(coalesce(new.body, ''), 500));
    n := n + 1;
  end loop;
  if n > 0 then
    update conversations set flagged = true where id = new.conversation_id;
    select coalesce(nullif(full_name, ''), 'User') into who from profiles where id = new.sender_id;
    for a in select id from profiles where role = 'admin' and status = 'active' loop
      perform push_notification(a, 'Security alert',
        who || ' shared or asked for contact details in a chat.',
        jsonb_build_object('security_flag', true, 'conversation_id', new.conversation_id, 'message_id', new.id));
    end loop;
  end if;
  return null;
end $$;

create or replace trigger messages_flag after insert on messages for each row execute function flag_message();

-- Dashboard views (admins only: the tables underneath are admin-readable only for other people's rows)
create or replace view admin_message_flags with (security_invoker = true) as
select f.*,
       s.full_name as sender_name, s.role as sender_role, s.phone as sender_phone,
       c.student_id, st.full_name as student_name, st.role as student_role,
       c.tutor_id, tu.full_name as tutor_name,
       m.body as message_body, m.created_at as message_at
from message_flags f
join conversations c on c.id = f.conversation_id
join messages m on m.id = f.message_id
left join profiles s on s.id = f.sender_id
left join profiles st on st.id = c.student_id
left join profiles tu on tu.id = c.tutor_id;

create or replace view admin_conversations with (security_invoker = true) as
select c.id, c.created_at, c.last_message_at, c.flagged,
       c.student_id, st.full_name as student_name, st.role as student_role, st.phone as student_phone, st.avatar_url as student_avatar,
       c.tutor_id, tu.full_name as tutor_name, tu.phone as tutor_phone, tu.avatar_url as tutor_avatar,
       (select count(*) from messages m where m.conversation_id = c.id) as message_count,
       (select count(*) from message_flags f where f.conversation_id = c.id) as flag_count,
       (select count(*) from message_flags f where f.conversation_id = c.id and f.status = 'new') as open_flags,
       (select m.kind::text from messages m where m.conversation_id = c.id order by m.created_at desc, m.id desc limit 1) as last_kind,
       (select m.body from messages m where m.conversation_id = c.id order by m.created_at desc, m.id desc limit 1) as last_body
from conversations c
left join profiles st on st.id = c.student_id
left join profiles tu on tu.id = c.tutor_id;

-- live alarm in the dashboard
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'message_flags') then
    alter publication supabase_realtime add table public.message_flags;
  end if;
end $$;

-- =====================================================================
-- 2) Working hours: each tutor sets the hours of every weekday (in their own local time)
-- =====================================================================
alter table tutor_profiles add column if not exists tz_offset_min int not null default 180
  check (tz_offset_min between -720 and 840);

-- Replace my weekly hours. p_slots = [{"weekday":0..6 (0 = Sunday), "start":"09:00", "end":"17:00"}, ...]
create or replace function set_working_hours(p_tz_offset int, p_slots jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare u uuid := me(); e jsonb;
begin
  if not exists (select 1 from tutor_profiles where user_id = u) then raise exception 'Only tutors have working hours'; end if;
  if p_tz_offset is null or p_tz_offset < -720 or p_tz_offset > 840 then raise exception 'Invalid time zone'; end if;
  update tutor_profiles set tz_offset_min = p_tz_offset where user_id = u;
  delete from availability_slots where tutor_id = u;
  for e in select * from jsonb_array_elements(coalesce(p_slots, '[]'::jsonb)) loop
    if (e->>'end')::time <= (e->>'start')::time and (e->>'end') not in ('24:00', '24:00:00') then
      raise exception 'Each period must end after it starts';
    end if;
    insert into availability_slots (tutor_id, weekday, start_time, end_time)
    values (u, (e->>'weekday')::int, (e->>'start')::time, (e->>'end')::time);
  end loop;
end $$;
revoke execute on function set_working_hours(int, jsonb) from public, anon;
grant execute on function set_working_hours(int, jsonb) to authenticated;

-- For booking: the tutor's weekly hours + the times already taken (no lesson details).
create or replace function tutor_schedule(p_tutor uuid, p_from timestamptz default now(), p_to timestamptz default now() + interval '15 days')
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'tz_offset', (select tz_offset_min from tutor_profiles where user_id = p_tutor),
    'slots', coalesce((select jsonb_agg(jsonb_build_object('weekday', weekday, 'start', to_char(start_time, 'HH24:MI'), 'end', to_char(end_time, 'HH24:MI')) order by weekday, start_time)
                       from availability_slots where tutor_id = p_tutor), '[]'::jsonb),
    'busy', coalesce((select jsonb_agg(jsonb_build_object('start', starts_at, 'end', starts_at + make_interval(mins => duration_min)))
                      from lessons where tutor_id = p_tutor and status in ('pending_payment', 'confirmed')
                        and starts_at < p_to and starts_at + make_interval(mins => duration_min) > p_from), '[]'::jsonb));
$$;
grant execute on function tutor_schedule(uuid, timestamptz, timestamptz) to anon, authenticated;

-- Bookings must also fall inside the tutor's working hours (when the tutor has set any).
create or replace function assert_slot_free(p_tutor uuid, p_start timestamptz, p_minutes int) returns void
language plpgsql stable security definer set search_path = public as $$
declare off int; loc timestamp; loc_end timestamp;
begin
  if p_start < now() then raise exception 'Choose a time in the future'; end if;
  if exists (select 1 from lessons
             where tutor_id = p_tutor and status in ('pending_payment', 'confirmed')
               and tstzrange(starts_at, starts_at + make_interval(mins => duration_min))
                && tstzrange(p_start, p_start + make_interval(mins => p_minutes))) then
    raise exception 'The tutor already has a lesson at this time';
  end if;
  if exists (select 1 from availability_slots where tutor_id = p_tutor) then
    select tz_offset_min into off from tutor_profiles where user_id = p_tutor;
    loc := (p_start at time zone 'UTC') + make_interval(mins => coalesce(off, 180));
    loc_end := loc + make_interval(mins => p_minutes);
    if not exists (
      select 1 from availability_slots s
      where s.tutor_id = p_tutor
        and s.weekday = extract(dow from loc)::int
        and s.start_time <= loc::time
        and case when loc_end::date > loc::date
                 then loc_end::time = '00:00'::time and s.end_time = '24:00'::time
                 else s.end_time >= loc_end::time end) then
      raise exception 'This time is outside the tutor''s working hours';
    end if;
  end if;
end $$;

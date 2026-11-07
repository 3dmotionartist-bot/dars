-- =====================================================================
-- Dars | درس — database schema (Supabase / Postgres 15+)
-- Tables, enums, indexes, helper triggers.  Security rules: 0002, logic: 0003.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------- enums ----------
create type user_role        as enum ('student', 'parent', 'tutor', 'admin');
create type account_status   as enum ('active', 'blocked', 'deleted');
create type verification     as enum ('pending', 'approved', 'rejected');
create type lesson_mode      as enum ('online', 'in_person');
create type lesson_status    as enum ('pending_payment', 'confirmed', 'delivered', 'cancelled', 'no_show', 'disputed');
create type package_status   as enum ('pending_payment', 'active', 'used_up', 'cancelled');
create type payment_method   as enum ('card', 'mada', 'apple_pay', 'bnpl', 'bank_transfer', 'wallet');
create type payment_status   as enum ('pending', 'under_review', 'paid', 'failed', 'refunded');
create type wallet_kind      as enum ('top_up', 'booking', 'refund', 'earning', 'payout', 'adjustment', 'referral');
create type payout_method    as enum ('bank_transfer', 'paypal', 'western_union');
create type payout_status    as enum ('requested', 'approved', 'paid', 'rejected');
create type live_status      as enum ('open', 'matched', 'cancelled', 'expired');
create type message_kind     as enum ('text', 'voice', 'file', 'image', 'system');
create type review_status    as enum ('visible', 'hidden');
create type report_status    as enum ('open', 'resolved', 'dismissed');
create type lead_status      as enum ('new', 'contacted', 'converted', 'closed');

-- ---------- catalog ----------
create table subjects (
  id          text primary key,
  name_ar     text not null,
  name_en     text not null,
  icon        text,
  color       text,
  sort        int  not null default 0,
  active      boolean not null default true
);

create table study_levels (
  id           text primary key,
  name_ar      text not null,
  name_en      text not null,
  price_factor numeric(4,2) not null default 1.0 check (price_factor > 0),
  sort         int not null default 0
);

create table curricula (
  id      text primary key,
  name_ar text not null,
  name_en text not null,
  sort    int not null default 0
);

-- ---------- people ----------
create table profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  role          user_role not null default 'student',
  full_name     text not null default '',
  phone         text unique,                 -- WhatsApp number, E.164
  email         text,
  gender        text check (gender in ('m', 'f')),
  country       text,
  city          text,
  locale        text not null default 'ar' check (locale in ('ar', 'en')),
  avatar_url    text,
  level_id      text references study_levels(id),
  curriculum_id text references curricula(id),
  status        account_status not null default 'active',
  referred_by   uuid references profiles(id),
  fcm_token     text,
  created_at    timestamptz not null default now()
);
create index on profiles (role);

create table tutor_profiles (
  user_id              uuid primary key references profiles(id) on delete cascade,
  headline             text not null default '' check (char_length(headline) <= 80),
  about                text not null default '' check (char_length(about) <= 1000),
  years_experience     int  not null default 0 check (years_experience between 0 and 60),
  languages            jsonb not null default '[]',         -- [{"code":"ar","level":"native"}]
  teaches_online       boolean not null default true,
  teaches_in_person    boolean not null default false,
  hourly_price         numeric(10,2) not null default 10 check (hourly_price > 0),   -- base (high-school) price
  currency             text not null default 'USD',
  max_package_discount int  not null default 0 check (max_package_discount between 0 and 50),
  instant_booking      boolean not null default true,
  cancel_hours         int  not null default 12 check (cancel_hours in (2,4,6,8,12,16,24,36,48,60,72)),
  verification         verification not null default 'pending',
  rejection_reason     text,
  verified_at          timestamptz,
  available_now        boolean not null default false,
  dnd_until            timestamptz,
  realtime_any_time    boolean not null default true,
  commission_rate      numeric(4,3),                        -- null = platform default
  video_url            text,
  cv_url               text,
  linkedin_url         text,
  rating_avg           numeric(3,2) not null default 0,
  rating_count         int not null default 0,
  minutes_taught       int not null default 0,
  created_at           timestamptz not null default now()
);
create index on tutor_profiles (verification);

create table tutor_subjects (
  tutor_id   uuid references tutor_profiles(user_id) on delete cascade,
  subject_id text references subjects(id),
  primary key (tutor_id, subject_id)
);

create table tutor_curricula (
  tutor_id      uuid references tutor_profiles(user_id) on delete cascade,
  curriculum_id text references curricula(id),
  primary key (tutor_id, curriculum_id)
);

create table tutor_level_prices (           -- optional per-level override of hourly_price × factor
  tutor_id uuid references tutor_profiles(user_id) on delete cascade,
  level_id text references study_levels(id),
  price    numeric(10,2) not null check (price > 0),
  primary key (tutor_id, level_id)
);

create table availability_slots (
  id         bigint generated always as identity primary key,
  tutor_id   uuid not null references tutor_profiles(user_id) on delete cascade,
  weekday    int  not null check (weekday between 0 and 6),   -- 0 = Sunday
  start_time time not null,
  end_time   time not null,
  check (end_time > start_time)
);

-- ---------- money & lessons ----------
create table packages (
  id           uuid primary key default gen_random_uuid(),
  student_id   uuid not null references profiles(id),
  tutor_id     uuid not null references tutor_profiles(user_id),
  level_id     text references study_levels(id),
  total_hours  int not null check (total_hours >= 4),
  used_minutes int not null default 0,
  discount_pct int not null default 0,
  price        numeric(10,2) not null,
  status       package_status not null default 'pending_payment',
  created_at   timestamptz not null default now()
);
create index on packages (student_id);
create index on packages (tutor_id);

create table lessons (
  id             uuid primary key default gen_random_uuid(),
  number         bigint generated always as identity unique,
  student_id     uuid not null references profiles(id),
  tutor_id       uuid not null references tutor_profiles(user_id),
  package_id     uuid references packages(id),
  subject_id     text references subjects(id),
  level_id       text references study_levels(id),
  starts_at      timestamptz not null,
  duration_min   int not null check (duration_min between 20 and 180),
  mode           lesson_mode not null default 'online',
  status         lesson_status not null default 'pending_payment',
  price          numeric(10,2) not null check (price >= 0),
  commission     numeric(10,2) not null default 0,
  meeting_url    text,
  recording_url  text,
  notes          text,
  cancelled_by   uuid references profiles(id),
  cancel_reason  text,
  delivered_at   timestamptz,
  created_at     timestamptz not null default now()
);
create index on lessons (student_id, starts_at);
create index on lessons (tutor_id, starts_at);
create index on lessons (status);

create table payments (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references profiles(id),
  lesson_id    uuid references lessons(id),
  package_id   uuid references packages(id),
  amount       numeric(10,2) not null check (amount >= 0),
  currency     text not null default 'USD',
  method       payment_method not null,
  status       payment_status not null default 'pending',
  provider     text,
  provider_ref text,
  receipt_url  text,
  created_at   timestamptz not null default now(),
  paid_at      timestamptz,
  check (lesson_id is not null or package_id is not null)
);
create index on payments (status);

create table wallet_transactions (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references profiles(id),
  amount     numeric(10,2) not null,              -- + credit, − debit
  kind       wallet_kind not null,
  lesson_id  uuid references lessons(id),
  payment_id uuid references payments(id),
  payout_id  uuid,
  note       text,
  created_at timestamptz not null default now()
);
create index on wallet_transactions (user_id);

create table payouts (
  id           uuid primary key default gen_random_uuid(),
  tutor_id     uuid not null references tutor_profiles(user_id),
  amount       numeric(10,2) not null check (amount > 0),
  method       payout_method not null,
  details      jsonb not null default '{}',       -- IBAN / PayPal email …
  status       payout_status not null default 'requested',
  admin_note   text,
  processed_by uuid references profiles(id),
  processed_at timestamptz,
  created_at   timestamptz not null default now()
);

-- ---------- live help ----------
create table live_requests (
  id          uuid primary key default gen_random_uuid(),
  student_id  uuid not null references profiles(id),
  subject_id  text references subjects(id),
  level_id    text references study_levels(id),
  body        text check (char_length(body) <= 400),
  voice_url   text,
  voice_sec   int,
  photo_url   text,
  status      live_status not null default 'open',
  expires_at  timestamptz not null,
  created_at  timestamptz not null default now(),
  check (coalesce(body, '') <> '' or voice_url is not null)
);
create index on live_requests (status, expires_at);

create table live_responses (
  request_id uuid references live_requests(id) on delete cascade,
  tutor_id   uuid references tutor_profiles(user_id),
  accepted   boolean not null,
  created_at timestamptz not null default now(),
  primary key (request_id, tutor_id)
);

-- ---------- chat ----------
create table conversations (
  id              uuid primary key default gen_random_uuid(),
  student_id      uuid not null references profiles(id),
  tutor_id        uuid not null references tutor_profiles(user_id),
  last_message_at timestamptz not null default now(),
  flagged         boolean not null default false,
  created_at      timestamptz not null default now(),
  unique (student_id, tutor_id)
);

create table messages (
  id              bigint generated always as identity primary key,
  conversation_id uuid not null references conversations(id) on delete cascade,
  sender_id       uuid references profiles(id),          -- null = system
  kind            message_kind not null default 'text',
  body            text,
  file_url        text,
  duration_sec    int,
  blocked         boolean not null default false,        -- contact-info filter hit
  read_at         timestamptz,
  created_at      timestamptz not null default now()
);
create index on messages (conversation_id, created_at);

-- ---------- quality ----------
create table reviews (
  id         uuid primary key default gen_random_uuid(),
  lesson_id  uuid not null unique references lessons(id),
  student_id uuid not null references profiles(id),
  tutor_id   uuid not null references tutor_profiles(user_id),
  stars      int  not null check (stars between 1 and 5),
  comment    text check (char_length(comment) <= 1000),
  status     review_status not null default 'visible',
  created_at timestamptz not null default now()
);
create index on reviews (tutor_id);

create table reports (
  id              uuid primary key default gen_random_uuid(),
  reporter_id     uuid not null references profiles(id),
  target_type     text not null check (target_type in ('conversation', 'lesson', 'user', 'review')),
  target_id       text not null,
  reason          text not null,
  status          report_status not null default 'open',
  resolution_note text,
  resolved_by     uuid references profiles(id),
  resolved_at     timestamptz,
  created_at      timestamptz not null default now()
);

-- ---------- growth ----------
create table leads (                     -- "Help me find a tutor" form
  id          uuid primary key default gen_random_uuid(),
  full_name   text not null,
  whatsapp    text not null,
  city        text,
  who         text check (who in ('student', 'parent')),
  level_id    text references study_levels(id),
  subject_id  text references subjects(id),
  reason      text,
  mode        text check (mode in ('online', 'in_person', 'both')),
  notes       text,
  status      lead_status not null default 'new',
  assigned_to uuid references profiles(id),
  created_at  timestamptz not null default now()
);

create table notifications (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references profiles(id) on delete cascade,
  title      text not null,
  body       text not null,
  data       jsonb not null default '{}',
  read_at    timestamptz,
  created_at timestamptz not null default now()
);
create index on notifications (user_id, created_at desc);

create table app_settings (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now()
);

create table audit_log (
  id         bigint generated always as identity primary key,
  actor_id   uuid references profiles(id),
  action     text not null,
  target     text,
  data       jsonb not null default '{}',
  created_at timestamptz not null default now()
);

-- ---------- defaults ----------
insert into app_settings (key, value) values
  ('commission_rate',        '0.15'),
  ('vat_rate',               '0'),
  ('live_request_seconds',   '90'),
  ('live_max_tutors',        '5'),
  ('pending_payment_hours',  '48'),
  ('first_hour_guarantee',   'true'),
  ('referral_commission',    '0.10'),
  ('support_whatsapp',       '"+963000000000"');

-- ---------- helper triggers ----------

-- New auth user → profile (role / name / phone from sign-up metadata)
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  r user_role := coalesce(nullif(new.raw_user_meta_data->>'role', ''), 'student')::user_role;
begin
  if r = 'admin' then r := 'student'; end if;          -- admins are promoted manually
  insert into profiles (id, role, full_name, phone, email)
  values (new.id, r,
          coalesce(new.raw_user_meta_data->>'full_name', ''),
          coalesce(new.phone, new.raw_user_meta_data->>'phone'),
          new.email);
  if r = 'tutor' then
    insert into tutor_profiles (user_id) values (new.id);
  end if;
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- Keep tutor rating in sync with visible reviews
create or replace function refresh_tutor_rating() returns trigger
language plpgsql security definer set search_path = public as $$
declare t uuid := coalesce(new.tutor_id, old.tutor_id);
begin
  update tutor_profiles tp set
    rating_avg   = coalesce((select round(avg(stars)::numeric, 2) from reviews where tutor_id = t and status = 'visible'), 0),
    rating_count = (select count(*) from reviews where tutor_id = t and status = 'visible')
  where tp.user_id = t;
  return null;
end $$;

create trigger reviews_rating
  after insert or update or delete on reviews
  for each row execute function refresh_tutor_rating();

-- Contact-info filter for chat (phones / emails / social handles) + bump conversation
create or replace function filter_message() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.kind = 'text' and new.sender_id is not null and (
       new.body ~ '(\+?\d[\d\s\-]{7,}\d)'
    or new.body ~* '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}'
    or new.body ~* '(wa\.me|whatsapp|t\.me|telegram|instagram\.com|snapchat)'
  ) then
    new.blocked := true;
  end if;
  update conversations set last_message_at = now() where id = new.conversation_id;
  return new;
end $$;

create trigger messages_filter
  before insert on messages
  for each row execute function filter_message();

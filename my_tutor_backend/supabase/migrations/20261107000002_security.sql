-- =====================================================================
-- Dars — Row Level Security, column guards, public views
-- Rule of thumb: clients READ through RLS; money/booking WRITES go through
-- the SECURITY DEFINER functions in 0003 (no direct insert policies).
-- =====================================================================

-- ---------- helpers ----------
create or replace function is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin' and status = 'active');
$$;

create or replace function my_role() returns user_role
language sql stable security definer set search_path = public as $$
  select role from profiles where id = auth.uid();
$$;

create or replace function is_approved_tutor() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from tutor_profiles t join profiles p on p.id = t.user_id
                 where t.user_id = auth.uid() and t.verification = 'approved' and p.status = 'active');
$$;

-- ---------- column guards (users cannot promote themselves or edit their own verification/rating) ----------
create or replace function guard_profile_update() returns trigger
language plpgsql as $$
begin
  -- current_user is 'authenticated' for app requests; inside SECURITY DEFINER functions it is the owner.
  if current_user in ('authenticated', 'anon') and not is_admin()
     and (new.role is distinct from old.role or new.status is distinct from old.status) then
    raise exception 'Only an admin can change role or account status';
  end if;
  return new;
end $$;
create trigger profiles_guard before update on profiles for each row execute function guard_profile_update();

create or replace function guard_tutor_update() returns trigger
language plpgsql as $$
begin
  if current_user in ('authenticated', 'anon') and not is_admin() and (
       new.verification     is distinct from old.verification
    or new.rejection_reason is distinct from old.rejection_reason
    or new.verified_at      is distinct from old.verified_at
    or new.rating_avg       is distinct from old.rating_avg
    or new.rating_count     is distinct from old.rating_count
    or new.minutes_taught   is distinct from old.minutes_taught
    or new.commission_rate  is distinct from old.commission_rate) then
    raise exception 'These tutor fields are managed by Dars';
  end if;
  -- Once approved, price/subject edits are allowed but the profile stays approved.
  return new;
end $$;
create trigger tutor_profiles_guard before update on tutor_profiles for each row execute function guard_tutor_update();

-- ---------- enable RLS everywhere ----------
alter table subjects            enable row level security;
alter table study_levels        enable row level security;
alter table curricula           enable row level security;
alter table profiles            enable row level security;
alter table tutor_profiles      enable row level security;
alter table tutor_subjects      enable row level security;
alter table tutor_curricula     enable row level security;
alter table tutor_level_prices  enable row level security;
alter table availability_slots  enable row level security;
alter table packages            enable row level security;
alter table lessons             enable row level security;
alter table payments            enable row level security;
alter table wallet_transactions enable row level security;
alter table payouts             enable row level security;
alter table live_requests       enable row level security;
alter table live_responses      enable row level security;
alter table conversations       enable row level security;
alter table messages            enable row level security;
alter table reviews             enable row level security;
alter table reports             enable row level security;
alter table leads               enable row level security;
alter table notifications       enable row level security;
alter table app_settings        enable row level security;
alter table audit_log           enable row level security;

-- ---------- admin: full access on every table ----------
do $$
declare t text;
begin
  foreach t in array array['subjects','study_levels','curricula','profiles','tutor_profiles','tutor_subjects',
    'tutor_curricula','tutor_level_prices','availability_slots','packages','lessons','payments',
    'wallet_transactions','payouts','live_requests','live_responses','conversations','messages','reviews',
    'reports','leads','notifications','app_settings','audit_log'] loop
    execute format('create policy admin_all on %I for all to authenticated using (is_admin()) with check (is_admin())', t);
  end loop;
end $$;

-- ---------- catalog: readable by everyone ----------
create policy read_all on subjects     for select to anon, authenticated using (active or is_admin());
create policy read_all on study_levels for select to anon, authenticated using (true);
create policy read_all on curricula    for select to anon, authenticated using (true);
create policy read_all on app_settings for select to anon, authenticated using (true);

-- ---------- profiles ----------
create policy own_read on profiles for select to authenticated using (id = auth.uid());
create policy counterpart_read on profiles for select to authenticated using (
  exists (select 1 from conversations c where (c.student_id = auth.uid() and c.tutor_id = profiles.id)
                                            or (c.tutor_id = auth.uid() and c.student_id = profiles.id))
  or exists (select 1 from lessons l where (l.student_id = auth.uid() and l.tutor_id = profiles.id)
                                       or (l.tutor_id = auth.uid() and l.student_id = profiles.id))
);
create policy own_update on profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- ---------- tutors (public listing goes through view public_tutors) ----------
create policy approved_read on tutor_profiles for select to anon, authenticated using (verification = 'approved' or user_id = auth.uid());
create policy own_update on tutor_profiles for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

do $$
declare t text;
begin
  foreach t in array array['tutor_subjects','tutor_curricula','tutor_level_prices','availability_slots'] loop
    execute format('create policy read_all on %I for select to anon, authenticated using (true)', t);
    execute format('create policy own_write on %I for all to authenticated using (tutor_id = auth.uid()) with check (tutor_id = auth.uid())', t);
  end loop;
end $$;

-- ---------- lessons, packages, money ----------
create policy party_read on lessons  for select to authenticated using (auth.uid() in (student_id, tutor_id));
create policy party_read on packages for select to authenticated using (auth.uid() in (student_id, tutor_id));
create policy own_read on payments            for select to authenticated using (user_id = auth.uid());
create policy own_read on wallet_transactions for select to authenticated using (user_id = auth.uid());
create policy own_read on payouts             for select to authenticated using (tutor_id = auth.uid());

-- ---------- live help ----------
create policy own_read on live_requests for select to authenticated using (student_id = auth.uid());
create policy tutors_see_open on live_requests for select to authenticated
  using (status = 'open' and expires_at > now() and is_approved_tutor());
-- Helpers are SECURITY DEFINER so the two policies below don't call each other in a loop.
create or replace function responded_to_live(p_request uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from live_responses where request_id = p_request and tutor_id = auth.uid());
$$;
create or replace function owns_live_request(p_request uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from live_requests where id = p_request and student_id = auth.uid());
$$;
create policy tutor_read on live_requests for select to authenticated using (responded_to_live(id));
create policy party_read on live_responses for select to authenticated using (tutor_id = auth.uid() or owns_live_request(request_id));

-- ---------- chat ----------
create policy party_read on conversations for select to authenticated using (auth.uid() in (student_id, tutor_id));
create policy party_read on messages for select to authenticated using (
  exists (select 1 from conversations c where c.id = conversation_id and auth.uid() in (c.student_id, c.tutor_id))
  and (not blocked or sender_id = auth.uid()));
create policy party_send on messages for insert to authenticated with check (
  sender_id = auth.uid() and kind <> 'system'
  and exists (select 1 from conversations c where c.id = conversation_id and auth.uid() in (c.student_id, c.tutor_id)));
create policy party_mark_read on messages for update to authenticated using (
  exists (select 1 from conversations c where c.id = conversation_id and auth.uid() in (c.student_id, c.tutor_id)))
  with check (true);

-- ---------- quality ----------
create policy public_read on reviews for select to anon, authenticated using (status = 'visible' or student_id = auth.uid());
create policy own_create on reports for insert to authenticated with check (reporter_id = auth.uid());
create policy own_read on reports for select to authenticated using (reporter_id = auth.uid());

-- ---------- growth & inbox ----------
create policy anyone_submit on leads for insert to anon, authenticated with check (status = 'new' and assigned_to is null);
create policy own_read on notifications for select to authenticated using (user_id = auth.uid());
create policy own_mark_read on notifications for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------- views ----------
-- Public tutor cards (definer view: exposes only safe columns of approved, active tutors)
create view public_tutors as
select t.user_id as id, p.full_name, p.avatar_url, p.gender, p.country,
       t.headline, t.about, t.years_experience, t.languages, t.teaches_online, t.teaches_in_person,
       t.hourly_price, t.currency, t.max_package_discount, t.instant_booking, t.cancel_hours,
       t.available_now and (t.dnd_until is null or t.dnd_until < now()) as available_now,
       t.rating_avg, t.rating_count, round(t.minutes_taught / 60.0) as hours_taught, t.video_url,
       (t.verified_at > now() - interval '30 days') as is_new,
       coalesce((select array_agg(subject_id order by subject_id) from tutor_subjects s where s.tutor_id = t.user_id), '{}') as subject_ids,
       coalesce((select array_agg(curriculum_id) from tutor_curricula c where c.tutor_id = t.user_id), '{}') as curriculum_ids,
       (select count(distinct student_id) from lessons l where l.tutor_id = t.user_id and l.status = 'delivered') as students
from tutor_profiles t join profiles p on p.id = t.user_id
where t.verification = 'approved' and p.status = 'active';

-- Wallet balance per user (invoker view → RLS of wallet_transactions applies)
create view wallet_balances with (security_invoker = true) as
select user_id, coalesce(sum(amount), 0)::numeric(10,2) as balance
from wallet_transactions group by user_id;

-- Admin lists with names (invoker → only admins see every row)
create view admin_lessons with (security_invoker = true) as
select l.*, s.full_name as student_name, s.phone as student_phone, t.full_name as tutor_name
from lessons l join profiles s on s.id = l.student_id join profiles t on t.id = l.tutor_id;

create view admin_tutors with (security_invoker = true) as
select tp.*, p.full_name, p.phone, p.email, p.city, p.country, p.status as account_status, p.created_at as joined_at,
       coalesce((select array_agg(subject_id) from tutor_subjects s where s.tutor_id = tp.user_id), '{}') as subject_ids
from tutor_profiles tp join profiles p on p.id = tp.user_id;

create view admin_payouts with (security_invoker = true) as
select po.*, p.full_name as tutor_name, p.phone as tutor_phone,
       (select coalesce(sum(amount), 0) from wallet_transactions w where w.user_id = po.tutor_id) as tutor_balance
from payouts po join profiles p on p.id = po.tutor_id;

create view admin_payments with (security_invoker = true) as
select pay.*, p.full_name as user_name, p.phone as user_phone
from payments pay join profiles p on p.id = pay.user_id;

create view admin_reviews with (security_invoker = true) as
select r.*, s.full_name as student_name, t.full_name as tutor_name
from reviews r join profiles s on s.id = r.student_id join profiles t on t.id = r.tutor_id;

create view admin_live_requests with (security_invoker = true) as
select q.*, p.full_name as student_name,
       (select count(*) from live_responses r where r.request_id = q.id and r.accepted) as accepted_count
from live_requests q join profiles p on p.id = q.student_id;

grant select on public_tutors to anon, authenticated;

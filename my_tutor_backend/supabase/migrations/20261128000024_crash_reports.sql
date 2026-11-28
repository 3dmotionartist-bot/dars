-- Round H2: crash reporting without an outside service. When the app hits an error it sends a short report
-- (the error, where in the code, the app build, phone or web) to this table; only admins can read it.
-- No message text, no chat content, no personal data is sent: only the error and the code location.
-- Safe to run once (and harmless if run again). Deletes no data except reports older than 90 days.
-- Old app versions keep working (they never send reports).

create table if not exists app_errors (
  id         bigserial primary key,
  user_id    uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  build      int,
  platform   text,
  message    text not null,
  stack      text,
  context    text
);
create index if not exists app_errors_time on app_errors (created_at desc);
create index if not exists app_errors_user_time on app_errors (user_id, created_at desc);
alter table app_errors enable row level security;
revoke all on app_errors from public, anon, authenticated;
grant select on app_errors to authenticated;
drop policy if exists admin_read on app_errors;
create policy admin_read on app_errors for select to authenticated using ((select is_admin()));

-- The app sends a report. At most 20 an hour per person (300 an hour from signed-out visitors together),
-- and the same error from the same person is kept once an hour, so a broken screen cannot flood the table.
create or replace function report_app_error(p_message text, p_stack text default null, p_build int default null,
                                            p_platform text default null, p_context text default null)
returns void language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); msg text := left(trim(coalesce(p_message, '')), 1000);
begin
  if msg = '' then return; end if;
  if uid is not null then
    if (select count(*) from app_errors where user_id = uid and created_at > now() - interval '1 hour') >= 20 then return; end if;
  elsif (select count(*) from app_errors where user_id is null and created_at > now() - interval '1 hour') >= 300 then
    return;
  end if;
  if exists (select 1 from app_errors where user_id is not distinct from uid and message = msg
             and created_at > now() - interval '1 hour') then
    return;
  end if;
  insert into app_errors (user_id, build, platform, message, stack, context)
  values (uid, p_build, left(p_platform, 20), msg, left(p_stack, 4000), left(p_context, 200));
  if random() < 0.05 then delete from app_errors where created_at < now() - interval '90 days'; end if;
end $$;
revoke execute on function report_app_error(text, text, int, text, text) from public;
grant execute on function report_app_error(text, text, int, text, text) to anon, authenticated;

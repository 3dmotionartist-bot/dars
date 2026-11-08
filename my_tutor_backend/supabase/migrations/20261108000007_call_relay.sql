-- Call relay (TURN) settings: entered by the admin in the dashboard (Settings),
-- handed only to signed-in users when a call starts. Never readable by anonymous visitors.
drop policy if exists read_all on app_settings;
create policy read_all on app_settings for select to anon, authenticated using (key not like 'turn\_%');

create or replace function call_ice_servers() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  urls text := (select value #>> '{}' from app_settings where key = 'turn_urls');
  usr  text := (select value #>> '{}' from app_settings where key = 'turn_username');
  cred text := (select value #>> '{}' from app_settings where key = 'turn_credential');
  list jsonb;
begin
  if auth.uid() is null or coalesce(trim(urls), '') = '' then return '[]'::jsonb; end if;
  select coalesce(jsonb_agg(trim(u)), '[]'::jsonb) into list
    from unnest(regexp_split_to_array(urls, '[,\s]+')) u where trim(u) ~ '^turns?:';
  if jsonb_array_length(list) = 0 then return '[]'::jsonb; end if;
  return jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('urls', list, 'username', nullif(usr, ''), 'credential', nullif(cred, ''))));
end $$;
revoke execute on function call_ice_servers() from public, anon;
grant execute on function call_ice_servers() to authenticated;

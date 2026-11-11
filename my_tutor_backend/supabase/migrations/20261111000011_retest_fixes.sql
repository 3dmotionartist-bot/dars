-- =====================================================================
-- Dars — follow-up to the "fix this week" update (from the reviewer's retest).
-- Safe to run once in the Supabase SQL editor. It deletes no data.
-- =====================================================================

-- 1. Nobody could see it, but anyone (even visitors) could call the helper that raises a
--    "shared contact details" alarm, and so raise a false alarm against an innocent person.
--    Internal helpers are now callable only from inside the server's own functions.
revoke execute on function flag_live_request_internal(uuid, uuid, text) from public, anon, authenticated;
revoke execute on function assert_slot_free(uuid, timestamptz, int), assert_bookable_tutor(uuid) from public, anon, authenticated;

-- 2. A call invitation could carry a phone number as its "room name" (e.g. "voice:0944555666").
--    Only the app's own room format is accepted now: four groups of five letters, like
--    "video:kqzpt-mwhra-bcdeg-xyzab" (the app never uses i, l or o, and never digits).
create or replace function filter_message() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.created_at := now();
  new.read_at := null;
  new.blocked := false;
  if new.sender_id is not null then
    if new.kind = 'call' then
      if coalesce(new.body, '') !~ '^(video|voice|meet):[a-hjkmnp-z]{5}(-[a-hjkmnp-z]{5}){3}$' then
        raise exception 'Invalid call message';
      end if;
      new.file_url := null;
    elsif new.kind in ('voice', 'image', 'file') then
      if coalesce(new.file_url, '') !~ ('^(chat-files|voice-notes)/' || new.sender_id::text || '/'
                                         || new.conversation_id::text || '/[0-9]{10,16}\.[a-z0-9]{2,5}$') then
        raise exception 'Files must be sent from the Dars app';
      end if;
      -- The label is set here, so a file name or caption cannot carry a phone number.
      new.body := case
        when new.kind = 'voice' then '🎤'
        when new.kind = 'image' then '📷'
        when new.file_url ~* '\.(mp4|mov|m4v|webm|3gp|mkv)$' then '🎬'
        else '📎' end;
    else
      new.file_url := null;
      if exists (select 1 from jsonb_array_elements(contact_hits(new.body)) e where e->>'kind' in ('phone', 'email', 'link')) then
        new.blocked := true;
      end if;
    end if;
  end if;
  update conversations set last_message_at = now() where id = new.conversation_id;
  return new;
end $$;

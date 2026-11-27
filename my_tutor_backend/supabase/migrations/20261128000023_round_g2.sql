-- Round G (part 2) — chat files and presence: PDF / Word / Excel / PowerPoint / text files in a chat (the admins
-- see each document in their flags list, because the contact filter cannot read inside a file), and "last seen".
-- Safe to run once (and harmless if run again). Deletes no data. Old app versions keep working: they never send
-- documents and never ask for "last seen".

-- 1. The chat-files bucket also takes documents (still 50 MB at most).
do $$
begin
  if to_regclass('storage.buckets') is null then return; end if;
  update storage.buckets
  set allowed_mime_types = array[
    'image/*', 'video/*', 'application/pdf', 'text/plain',
    'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint', 'application/vnd.openxmlformats-officedocument.presentationml.presentation']
  where id = 'chat-files';
end $$;

-- 2. A document sent in a chat goes to the admins' flags list (no alert: homework PDFs are normal), so a phone
--    number written inside a file can still be found by a person.
create or replace function flag_chat_document() returns trigger
language plpgsql security definer set search_path = public as $$
declare ext text;
begin
  ext := lower(substring(coalesce(new.file_url, '') from '\.([a-z0-9]{2,5})$'));
  if new.kind = 'file' and new.sender_id is not null
     and ext in ('pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt') then
    insert into message_flags (message_id, conversation_id, sender_id, kind, matched, excerpt)
    values (new.id, new.conversation_id, new.sender_id, 'possible', 'document', ext);
  end if;
  return new;
end $$;
revoke execute on function flag_chat_document() from public, anon, authenticated;
drop trigger if exists messages_flag_document on messages;
create trigger messages_flag_document after insert on messages for each row execute function flag_chat_document();

-- 3. "Last seen": when each person last had Dars open. Only the two people of a chat can see each other's.
create table if not exists presence (
  user_id      uuid primary key references profiles(id) on delete cascade,
  last_seen_at timestamptz not null default now()
);
alter table presence enable row level security;
revoke all on presence from public, anon, authenticated;

-- The app calls this while it is open (at most once a minute is written).
create or replace function touch_presence() returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return; end if;
  insert into presence (user_id, last_seen_at) values (auth.uid(), now())
  on conflict (user_id) do update set last_seen_at = now()
  where presence.last_seen_at < now() - interval '50 seconds';
end $$;
revoke execute on function touch_presence() from public, anon;
grant execute on function touch_presence() to authenticated;

-- When the other person of one of my chats was last seen (null if never, or not someone I chat with).
create or replace function last_seen(p_user uuid) returns timestamptz
language sql stable security definer set search_path = public as $$
  select p.last_seen_at from presence p
  where p.user_id = p_user
    and exists (select 1 from conversations c
                where (c.student_id = (select auth.uid()) and c.tutor_id = p_user)
                   or (c.tutor_id = (select auth.uid()) and c.student_id = p_user));
$$;
revoke execute on function last_seen(uuid) from public, anon;
grant execute on function last_seen(uuid) to authenticated;

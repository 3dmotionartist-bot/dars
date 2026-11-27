-- Round G (part 1) — chat comfort: reply to a message (quote), delete my own message (the admin keeps a copy).
-- Safe to run once (and harmless if run again). Deletes no data: a deleted message's text and file move to an
-- admin-only table. Old app versions keep working: they never set reply_to, and a deleted message reaches
-- them as an empty message (their bubble shows nothing for it).

alter table messages add column if not exists reply_to bigint references messages(id) on delete set null;
alter table messages add column if not exists deleted_at timestamptz;

-- A quote must point at a message of the same chat (else it is dropped); nobody sets deleted_at by hand.
create or replace function messages_reply_guard() returns trigger
language plpgsql set search_path = public as $$
begin
  new.deleted_at := null;
  if new.reply_to is not null and not exists (
       select 1 from messages m where m.id = new.reply_to and m.conversation_id = new.conversation_id) then
    new.reply_to := null;
  end if;
  return new;
end $$;
drop trigger if exists messages_reply on messages;
create trigger messages_reply before insert on messages for each row execute function messages_reply_guard();

-- What a deleted message said, for the admins only.
create table if not exists deleted_messages (
  message_id      bigint primary key references messages(id) on delete cascade,
  conversation_id uuid not null,
  sender_id       uuid,
  kind            message_kind not null,
  body            text,
  file_url        text,
  sent_at         timestamptz,
  deleted_at      timestamptz not null default now()
);
alter table deleted_messages enable row level security;
revoke all on deleted_messages from public, anon, authenticated;
grant select on deleted_messages to authenticated;
drop policy if exists admin_read on deleted_messages;
create policy admin_read on deleted_messages for select to authenticated using ((select is_admin()));  -- wrapped: once per query (Round A)

-- The sender deletes his own message for both people. Calls and system messages stay.
create or replace function delete_message(p_message bigint) returns void
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := auth.uid(); m messages%rowtype;
begin
  if u is null or not is_active_user() then raise exception 'Sign in first' using errcode = '42501'; end if;
  select * into m from messages where id = p_message for update;
  if m.id is null or m.sender_id is distinct from u then raise exception 'Message not found'; end if;
  if m.deleted_at is not null then return; end if;
  if m.kind in ('system', 'call') then raise exception 'This message cannot be deleted'; end if;
  insert into deleted_messages (message_id, conversation_id, sender_id, kind, body, file_url, sent_at)
  values (m.id, m.conversation_id, m.sender_id, m.kind, m.body, m.file_url, m.created_at)
  on conflict (message_id) do nothing;
  update messages set body = null, file_url = null, duration_sec = null, deleted_at = now() where id = m.id;
end $$;
revoke execute on function delete_message(bigint) from public, anon;
grant execute on function delete_message(bigint) to authenticated;

-- Arabic (Round H1 list). Negative ids come first, so these specific texts win over the general ones —
-- also in app builds 45–46, which read the list in id order.
insert into server_texts (id, pattern, ar) values
  (-7, '(.+) shared or asked for contact details in a chat\.', 'شارك \1 معلومات تواصل أو طلبها في محادثة.'),
  (-6, '(.+) shared or asked for contact details in a lesson link\.', 'شارك \1 معلومات تواصل أو طلبها في رابط درس.'),
  (-5, '(.+) shared or asked for contact details in a lesson summary\.', 'شارك \1 معلومات تواصل أو طلبها في ملخص درس.'),
  (-4, '(.+) shared or asked for contact details in a review reply\.', 'شارك \1 معلومات تواصل أو طلبها في ردّ على تقييم.'),
  (-3, '(.+) shared or asked for contact details in a review\.', 'شارك \1 معلومات تواصل أو طلبها في تقييم.'),
  (-2, '(.+) shared or asked for contact details in a tutor profile\.', 'شارك \1 معلومات تواصل أو طلبها في ملف مدرس.'),
  (1019, 'Message not found', 'الرسالة غير موجودة'),
  (1020, 'This message cannot be deleted', 'لا يمكن حذف هذه الرسالة')
on conflict (id) do update set pattern = excluded.pattern, ar = excluded.ar;

-- The newest messages of each chat, now with the quote and the "deleted" mark (same rows as before).
create or replace function recent_messages(p_conversations uuid[], p_limit int default 50)
returns setof messages language sql stable set search_path = public as $$
  select id, conversation_id, sender_id, kind, body, file_url, duration_sec, blocked, read_at, created_at, client_id,
         reply_to, deleted_at
  from (
    select m.*, row_number() over (partition by m.conversation_id order by m.created_at desc, m.id desc) as rn
    from messages m
    where m.conversation_id = any(p_conversations)
  ) x
  where rn <= least(greatest(coalesce(p_limit, 50), 1), 200)
  order by conversation_id, created_at, id;
$$;

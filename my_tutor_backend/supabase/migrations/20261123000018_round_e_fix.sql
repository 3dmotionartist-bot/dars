-- Round E fix (phone test 23 Nov 2026). Safe to run once (and harmless if run again). Deletes no data.
--
-- A number split over two messages ("0933", then "123456") got through when the sender had sent a whole
-- number shortly before: the earlier message was already hidden, so the recent text "already contained a
-- hidden number" and the split check stopped. That is the natural way to get around the filter (a number is
-- hidden → send it in pieces), so the recent text now leaves out messages that are hidden on their own; only
-- the pieces are read together.
create or replace function contact_recent_text(p_conv uuid, p_sender uuid, p_exclude bigint) returns text
language sql stable security definer set search_path = public as $$
  select string_agg(body, ' ' order by created_at, id) from (
    select body, created_at, id from messages
    where conversation_id = p_conv and sender_id = p_sender and kind = 'text' and id <> coalesce(p_exclude, -1)
      and created_at > now() - interval '2 minutes'
    order by created_at desc, id desc limit 5) x
  where not contact_hidden(body);
$$;
revoke execute on function contact_recent_text(uuid, uuid, bigint) from public, anon, authenticated;

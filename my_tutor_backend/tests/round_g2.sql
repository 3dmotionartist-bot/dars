-- Round G part 2: documents in a chat (flagged for the admins), "last seen".
\set QUIET on
\pset format unaligned
\pset tuples_only on
\set stu   '00000000-0000-0000-0000-0000000000b1'
\set tut   '00000000-0000-0000-0000-0000000000c1'
\set admin '00000000-0000-0000-0000-0000000000a1'

reset role;
update profiles set status = 'active' where id in (:'stu', :'tut');
select id as conv from conversations where student_id = :'stu' and tutor_id = :'tut' limit 1 \gset
select id as ostu from profiles
  where id <> :'tut' and id not in (select student_id from conversations where tutor_id = :'tut') limit 1 \gset

\echo '--- G2. documents in a chat'
select t_as(:'stu'); set role authenticated;
insert into messages (conversation_id, sender_id, kind, file_url)
  values (:'conv', :'stu', 'file', 'chat-files/' || :'stu' || '/' || :'conv' || '/1764200000001.pdf') returning id as d1 \gset
insert into messages (conversation_id, sender_id, kind, file_url)
  values (:'conv', :'stu', 'file', 'chat-files/' || :'stu' || '/' || :'conv' || '/1764200000002.docx') returning id as d2 \gset
insert into messages (conversation_id, sender_id, kind, file_url)
  values (:'conv', :'stu', 'file', 'chat-files/' || :'stu' || '/' || :'conv' || '/1764200000003.mp4') returning id as v1 \gset
insert into messages (conversation_id, sender_id, kind, file_url)
  values (:'conv', :'stu', 'image', 'chat-files/' || :'stu' || '/' || :'conv' || '/1764200000004.jpg') returning id as i1 \gset
reset role;
select t_ok((select body from messages where id = :d1) = '📎', 'a document keeps the file mark (no file name from the sender)');
select t_ok((select count(*) from message_flags where message_id = :d1 and kind = 'possible' and matched = 'document' and excerpt = 'pdf') = 1,
  'a PDF goes to the admins'' flags list');
select t_ok((select count(*) from message_flags where message_id = :d2 and excerpt = 'docx') = 1, 'so does a Word file');
select t_ok((select count(*) from message_flags where message_id in (:v1, :i1)) = 0, 'videos and photos are not flagged');
select t_as(:'stu'); set role authenticated;
select t_ok((select count(*) from message_flags) = 0, 'the sender cannot see the flags');
reset role;
select t_as(:'admin'); set role authenticated;
select t_ok((select count(*) from message_flags where message_id = :d1) = 1, 'an admin sees the flag');
reset role;
set role authenticated;
select t_err('select flag_chat_document()', 'permission denied', 'nobody calls the flag helper directly');
reset role;

\echo '--- G2. last seen'
delete from presence where user_id in (:'stu', :'tut', :'ostu');
select t_as(:'tut'); set role authenticated;
select t_ok(last_seen(:'stu') is null, 'never seen: nothing');
reset role;
select t_as(:'stu'); set role authenticated;
select touch_presence();
reset role;
select last_seen_at as first_seen from presence where user_id = :'stu' \gset
select t_ok(:'first_seen' is not null, 'opening the app records "last seen"');
select t_as(:'stu'); set role authenticated;
select touch_presence();
reset role;
select t_ok((select last_seen_at from presence where user_id = :'stu') = :'first_seen', 'within a minute nothing more is written');
update presence set last_seen_at = now() - interval '10 minutes' where user_id = :'stu';
select t_as(:'stu'); set role authenticated;
select touch_presence();
reset role;
select t_ok((select last_seen_at > now() - interval '1 minute' from presence where user_id = :'stu'), 'later it moves on');
select t_as(:'tut'); set role authenticated;
select t_ok(last_seen(:'stu') is not null, 'the other person of my chat sees my "last seen"');
select t_err('select count(*) from presence', 'permission denied', 'nobody reads the presence table directly');
reset role;
insert into presence (user_id) values (:'ostu') on conflict (user_id) do update set last_seen_at = now();
select t_as(:'tut'); set role authenticated;
select t_ok(last_seen(:'ostu') is null, 'someone I have no chat with: nothing');
reset role;
set role anon;
select t_err(format('select last_seen(%L)', :'stu'), 'permission denied', 'a visitor sees nothing');
select t_err('select touch_presence()', 'permission denied', 'a visitor writes nothing');
reset role;

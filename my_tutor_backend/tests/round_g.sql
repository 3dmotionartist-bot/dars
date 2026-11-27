-- Round G part 1: reply to a message, delete my own message (admins keep a copy).
\set QUIET on
\pset format unaligned
\pset tuples_only on
\set stu   '00000000-0000-0000-0000-0000000000b1'
\set tut   '00000000-0000-0000-0000-0000000000c1'
\set admin '00000000-0000-0000-0000-0000000000a1'

reset role;
update profiles set status = 'active' where id in (:'stu', :'tut');
select id as conv from conversations where student_id = :'stu' and tutor_id = :'tut' limit 1 \gset
select id as other from conversations where id <> :'conv' limit 1 \gset
insert into messages (conversation_id, sender_id, body) values (:'other', (select student_id from conversations where id = :'other'), 'elsewhere') returning id as om \gset

\echo '--- G1. reply to a message'
select t_as(:'stu'); set role authenticated;
insert into messages (conversation_id, sender_id, body) values (:'conv', :'stu', 'What is homework 3?') returning id as m1 \gset
reset role;
select t_as(:'tut'); set role authenticated;
insert into messages (conversation_id, sender_id, body, reply_to) values (:'conv', :'tut', 'Page 12', :m1) returning id as m2 \gset
insert into messages (conversation_id, sender_id, body, reply_to, deleted_at) values (:'conv', :'tut', 'x', :om, now()) returning id as m3 \gset
reset role;
select t_ok((select reply_to from messages where id = :m2) = :m1, 'a reply keeps the quoted message');
select t_ok((select reply_to is null and deleted_at is null from messages where id = :m3),
  'a quote of another chat''s message is dropped, and nobody marks a message deleted by hand');

\echo '--- G1. delete my own message'
select t_as(:'tut'); set role authenticated;
select t_err(format('select delete_message(%s)', :m1), 'Message not found', 'nobody deletes the other person''s message');
reset role;
select t_as(:'stu'); set role authenticated;
update messages set body = 'changed' where id = :m1;
reset role;
select t_ok((select body from messages where id = :m1) = 'What is homework 3?', 'a message still cannot be edited directly');
select t_as(:'stu'); set role authenticated;
select delete_message(:m1);
select delete_message(:m1);   -- twice: no error, nothing more happens
reset role;
select t_ok((select body is null and file_url is null and deleted_at is not null from messages where id = :m1), 'the text is gone for both people');
select t_ok((select body = 'What is homework 3?' and sender_id = :'stu' from deleted_messages where message_id = :m1), 'the admins keep a copy');
select t_ok((select count(*) from deleted_messages where message_id = :m1) = 1, 'one copy only');
select t_ok((select reply_to from messages where id = :m2) = :m1, 'the reply still points at it (shown as "deleted")');
select t_as(:'stu'); set role authenticated;
select t_ok((select count(*) from deleted_messages) = 0, 'the sender cannot read the admins'' copy');
reset role;
select t_as(:'tut'); set role authenticated;
select t_ok((select count(*) from deleted_messages) = 0, 'nor can the other person');
reset role;
select t_as(:'admin'); set role authenticated;
select t_ok((select count(*) from deleted_messages where message_id = :m1) = 1, 'an admin reads it');
reset role;
insert into messages (conversation_id, sender_id, kind, body) values (:'conv', null, 'system', 'Lesson booked') returning id as sm \gset
select t_as(:'stu'); set role authenticated;
select t_err(format('select delete_message(%s)', :sm), 'Message not found', 'system messages cannot be deleted');
reset role;
set role anon;
select t_err(format('select delete_message(%s)', :m2), 'permission denied', 'a visitor cannot delete');
reset role;
select t_ok(server_text_ar('Ali shared or asked for contact details in a chat.') = 'شارك Ali معلومات تواصل أو طلبها في محادثة.',
  'the security notice is all Arabic (no English "in a chat")');
select t_ok(server_text_ar('Ali shared or asked for contact details in a lesson summary.') like '%في ملخص درس.', 'and for every place');

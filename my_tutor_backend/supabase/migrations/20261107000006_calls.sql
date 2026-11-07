-- Voice / video calls: a call invitation is a chat message of kind 'call'
-- whose body is "video:<room>" or "voice:<room>". Both people open the same room on the call page.
alter type message_kind add value if not exists 'call';

alter table messages drop constraint if exists messages_call_body;
alter table messages add constraint messages_call_body
  check (kind::text <> 'call' or body ~ '^(video|voice):[a-zA-Z0-9-]{8,64}$');

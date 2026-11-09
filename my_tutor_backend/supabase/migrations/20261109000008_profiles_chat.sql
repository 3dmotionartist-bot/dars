-- Nobody can open a chat (or call) with themselves.
create or replace function start_conversation(p_tutor uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare u uuid := me();
begin
  if p_tutor = u then raise exception 'You cannot message yourself'; end if;
  perform assert_bookable_tutor(p_tutor);
  return ensure_conversation(u, p_tutor);
end $$;

-- A tutor can open the chat with any student who booked with them.
create or replace function tutor_start_conversation(p_student uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare u uuid := me();
begin
  if p_student = u then raise exception 'You cannot message yourself'; end if;
  if not exists (select 1 from lessons where tutor_id = u and student_id = p_student)
     and not exists (select 1 from packages where tutor_id = u and student_id = p_student)
     and not exists (select 1 from conversations where tutor_id = u and student_id = p_student) then
    raise exception 'This student has not booked with you';
  end if;
  return ensure_conversation(p_student, u);
end $$;
revoke execute on function tutor_start_conversation(uuid) from public, anon;
grant execute on function tutor_start_conversation(uuid) to authenticated;

-- New chats with yourself are blocked (existing rows are left untouched; the app hides them).
alter table conversations add constraint conversations_not_self check (student_id <> tutor_id) not valid;

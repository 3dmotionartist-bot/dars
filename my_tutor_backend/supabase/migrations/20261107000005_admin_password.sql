-- Admin: set a new password for any user (the admin tells the user the new password).
-- Passwords are stored only as one-way bcrypt hashes, so they can never be viewed — only replaced.
create or replace function admin_set_user_password(p_user uuid, p_password text)
returns void language plpgsql security definer set search_path = public, extensions as $$
begin
  perform require_admin();
  if p_password is null or char_length(p_password) < 6 then
    raise exception 'Password must be at least 6 characters';
  end if;
  update auth.users
     set encrypted_password = crypt(p_password, gen_salt('bf')), updated_at = now()
   where id = p_user;
  if not found then raise exception 'User not found'; end if;
  perform audit('user_password_reset', p_user::text);   -- the password itself is never logged
end $$;

revoke execute on function admin_set_user_password(uuid, text) from public, anon;
grant execute on function admin_set_user_password(uuid, text) to authenticated;

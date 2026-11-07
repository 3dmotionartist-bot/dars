-- =====================================================================
-- Dars — Supabase platform setup: scheduled jobs, file buckets, realtime.
-- Each block checks that the Supabase feature exists, so it is safe anywhere.
-- =====================================================================

-- ---------- scheduled jobs (pg_cron) ----------
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.schedule('dars-expire-live',     '* * * * *',  'select public.expire_live_requests()');
    perform cron.schedule('dars-expire-unpaid',   '7 * * * *',  'select public.expire_pending_payments()');
    perform cron.schedule('dars-auto-deliver',    '17 * * * *', 'select public.auto_deliver_lessons()');
  end if;
end $$;

-- ---------- storage buckets ----------
do $$
begin
  if to_regclass('storage.buckets') is null then return; end if;

  insert into storage.buckets (id, name, public) values
    ('avatars',     'avatars',     true),    -- profile photos (public)
    ('tutor-media', 'tutor-media', true),    -- intro videos (public)
    ('tutor-docs',  'tutor-docs',  false),   -- CVs, certificates (tutor + admins)
    ('voice-notes', 'voice-notes', false),   -- live-request & chat voice notes
    ('chat-files',  'chat-files',  false),   -- homework photos, PDFs
    ('receipts',    'receipts',    false)    -- bank-transfer receipts
  on conflict (id) do nothing;

  -- Files live under "<user id>/..." — owners write their own folder; admins read everything.
  execute $p$create policy "own folder write" on storage.objects for insert to authenticated
    with check (bucket_id in ('avatars','tutor-media','tutor-docs','voice-notes','chat-files','receipts')
                and (storage.foldername(name))[1] = auth.uid()::text)$p$;
  execute $p$create policy "own folder update" on storage.objects for update to authenticated
    using ((storage.foldername(name))[1] = auth.uid()::text)$p$;
  execute $p$create policy "own folder delete" on storage.objects for delete to authenticated
    using ((storage.foldername(name))[1] = auth.uid()::text)$p$;
  execute $p$create policy "public buckets read" on storage.objects for select to anon, authenticated
    using (bucket_id in ('avatars','tutor-media'))$p$;
  execute $p$create policy "own or admin read" on storage.objects for select to authenticated
    using ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin())$p$;
  -- Chat partners can read each other's chat files / voice notes; tutors can play live-request voice notes.
  execute $p$create policy "chat partner read" on storage.objects for select to authenticated
    using (bucket_id in ('chat-files','voice-notes') and exists (
      select 1 from public.conversations c
      where (c.student_id::text = (storage.foldername(name))[1] and c.tutor_id = auth.uid())
         or (c.tutor_id::text = (storage.foldername(name))[1] and c.student_id = auth.uid())))$p$;
  execute $p$create policy "live voice read" on storage.objects for select to authenticated
    using (bucket_id = 'voice-notes' and public.is_approved_tutor())$p$;
end $$;

-- ---------- realtime (live requests, chat, notifications push to apps instantly) ----------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.live_requests, public.live_responses,
      public.messages, public.conversations, public.notifications, public.lessons;
  end if;
end $$;

-- Round E — trust and safety.
-- Safe to run once (and harmless if run again). Deletes no data.
--
-- E1. Contact filter: only real phone numbers / contact details are hidden; times, dates, prices and maths pass.
--     Numbers split over several messages are caught; unsure cases are flagged for the admin without hiding.
--     The same rules now cover live-help questions, tutor headline / about, review comments and lesson links.

-- ── E1. Contact filter ─────────────────────────────────────────────────────────────────────────────────

-- Digits written in other scripts become 0–9; emoji keycaps (0️⃣) become plain digits.
create or replace function contact_light(p text) returns text
language sql immutable parallel safe set search_path = public as $$
  select replace(replace(translate(coalesce(p, ''),
    '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹０１２３４５６７８９𝟎𝟏𝟐𝟑𝟒𝟓𝟔𝟕𝟖𝟗𝟘𝟙𝟚𝟛𝟜𝟝𝟞𝟟𝟠𝟡𝟢𝟣𝟤𝟥𝟦𝟧𝟨𝟩𝟪𝟫𝟬𝟭𝟮𝟯𝟰𝟱𝟲𝟳𝟴𝟵𝟶𝟷𝟸𝟹𝟺𝟻𝟼𝟽𝟾𝟿',
    '01234567890123456789012345678901234567890123456789012345678901234567890123456789'),
    chr(65039), ''), chr(8419), '')
$$;

-- Text prepared for the phone check: lower case, number words → digits ("zero 9 three" → "0 9 3"),
-- look-alike letters inside numbers → digits ("o933 l23" → "0933 123"), single letters between digits →
-- separators ("0933a123" → "0933-123"), and times / dates / decimals taken out (they are never phones).
create or replace function contact_digits(p text) returns text
language plpgsql immutable parallel safe set search_path = public as $$
declare
  words constant jsonb := '{
    "zero":"0","oh":"0","one":"1","two":"2","three":"3","four":"4","five":"5","six":"6","seven":"7","eight":"8","nine":"9",
    "صفر":"0","زيرو":"0","واحد":"1","وحده":"1","وحدة":"1","اثنين":"2","اثنان":"2","إثنين":"2","ثنين":"2","تنين":"2","اتنين":"2",
    "ثلاثة":"3","ثلاثه":"3","ثلاث":"3","تلاتة":"3","تلاته":"3","تلات":"3",
    "اربعة":"4","أربعة":"4","اربعه":"4","أربعه":"4","اربع":"4","أربع":"4",
    "خمسة":"5","خمسه":"5","خمس":"5","ستة":"6","سته":"6","سبعة":"7","سبعه":"7","سبع":"7",
    "ثمانية":"8","ثمانيه":"8","ثمنية":"8","تمانية":"8","تمانيه":"8","ثمان":"8","تسعة":"9","تسعه":"9","تسع":"9"}';
  b text;
  out text := '';
  tok text;
  core text;
  d text;
begin
  b := lower(contact_light(p));
  for tok in select regexp_split_to_table(b, '\s+') loop
    core := regexp_replace(tok, '^[^a-z0-9ء-ي]+|[^a-z0-9ء-ي]+$', '', 'g');
    d := words ->> core;
    if d is null and left(core, 1) = 'و' then d := words ->> substr(core, 2); end if;   -- "وخمسة" = "and five"
    if d is not null then
      tok := d;
    elsif tok ~ '\d' and tok ~ '^[0-9oli+().,*/_-]+$' then
      tok := translate(tok, 'oli', '011');
    end if;
    out := out || ' ' || tok;
  end loop;
  -- web addresses and IDs are not phone numbers (contact links are caught by the link rules)
  out := regexp_replace(out, '(https?://|www\.)\S+', ' ¦ ', 'g');
  out := regexp_replace(out, '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', ' ¦ ', 'g');
  -- a single letter between digits is a separator
  out := regexp_replace(out, '(\d) ?[a-zء-ي] ?(?=\d)', '\1-', 'g');
  -- dates (2026-11-12, 12/11/2026), day/month (10/11), times (10:30, 10.30) and decimals (3.14159) are not phones
  out := regexp_replace(out, '(?<![\d.,:/-])(19|20)\d\d[-/.]\d{1,2}[-/.]\d{1,2}(?!\d|[-/.,]\d)', ' ¦ ', 'g');
  out := regexp_replace(out, '(?<![\d.,:/-])\d{1,2}[-/.]\d{1,2}[-/.]((19|20)\d\d|\d\d)(?!\d|[-/.,]\d)', ' ¦ ', 'g');
  out := regexp_replace(out, '(?<![\d.,:/-])\d{1,2}[:.]\d\d(:\d\d)?(?!\d|[:.,/-]\d)', ' ¦ ', 'g');
  out := regexp_replace(out, '(?<![\d.,:/-])\d{1,2}/\d{1,2}(?!\d|[/.,-]\d)', ' ¦ ', 'g');
  out := regexp_replace(out, '(?<![\d.,])(0|[1-9]\d*)[.,]\d+(?!\d|[.,]\d)', ' ¦ ', 'g');
  return out;
end $$;

-- The phone check on one run of digits and separators. 'sure' = hide; 'possible' = flag only; null = no phone.
-- A phone starts with +, 00 or 0 and has 9–13 digits (00 + country code: up to 15; also 9639… without the +). Counting sequences
-- (2 4 6 8 …) and prices with thousands separators (15.000.000) are never phones.
create or replace function contact_phone_run(r text) returns text
language plpgsql immutable parallel safe set search_path = public as $$
declare
  g text[];
  n int;
  i int;
  j int;
  d text;
  k int;
  ap boolean;
  best text := null;
begin
  if r ~ '^\d{1,3}([.,]\d{3})+$' then return null; end if;
  g := array(select (regexp_matches(r, '\+?\d+', 'g'))[1]);
  n := coalesce(array_length(g, 1), 0);
  for i in 1 .. n loop
    continue when not (left(g[i], 1) = '+' or g[i] ~ '^(0|9)');
    continue when g[i] ~ '^0{3,}$';                      -- "000" inside a price is not a phone start
    d := '';
    for j in i .. n loop
      d := d || ltrim(g[j], '+');
      exit when length(d) > 15;
      -- a counting sequence (equal steps) is maths, not a phone
      if j - i >= 2 then
        ap := true;
        for k in i + 2 .. j loop
          if ltrim(g[k], '+')::numeric - ltrim(g[k - 1], '+')::numeric
             <> ltrim(g[i + 1], '+')::numeric - ltrim(g[i], '+')::numeric
             or ltrim(g[i + 1], '+')::numeric = ltrim(g[i], '+')::numeric then
            ap := false; exit;
          end if;
        end loop;
        continue when ap;
      end if;
      if length(d) between 9 and 13 and (left(g[i], 1) = '+' or g[i] ~ '^0') then return 'sure'; end if;
      if g[i] ~ '^00' and length(d) between 11 and 15 then return 'sure'; end if;   -- 00 + country code
      if d ~ '^(00)?9639\d{8}$' then return 'sure'; end if;
      if best is null and j = n and (d ~ '^9\d{8}$' or (g[i] ~ '^0' and length(d) between 7 and 8)) then
        best := 'possible';
      end if;
    end loop;
  end loop;
  return best;
end $$;

-- What a text contains: [{"kind": "phone"|"possible"|"email"|"handle"|"link"|"contact_request",
--                         "matched": "...", "sure": true|false}]
-- sure = hidden from the other person and flagged; not sure = only flagged for the admin.
create or replace function contact_hits(p_body text) returns jsonb
language plpgsql immutable parallel safe set search_path = public as $$
declare
  hits jsonb := '[]';
  lb text;
  dg text;
  r text;
  v text;
  possible text := null;
  m text;
begin
  if p_body is null or btrim(p_body) = '' then return hits; end if;
  lb := lower(contact_light(p_body));
  dg := contact_digits(p_body);

  -- phone numbers
  for r in select (regexp_matches(dg, '\+?\d(?:[\s().,*/_+-]*\d)*', 'g'))[1] loop
    v := contact_phone_run(r);
    if v = 'sure' then
      hits := hits || jsonb_build_array(jsonb_build_object('kind', 'phone', 'matched', left(btrim(r), 120), 'sure', true));
      possible := null;
      exit;
    elsif v = 'possible' and possible is null then
      possible := btrim(r);
    end if;
  end loop;
  if possible is not null then
    hits := hits || jsonb_build_array(jsonb_build_object('kind', 'possible', 'matched', left(possible, 120), 'sure', false));
  end if;

  -- e-mail addresses, also written out ("ahmad at gmail dot com", "ahmad @ gmail . com")
  m := substring(lb from '([a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,})');
  if m is null then
    m := substring(lb from '([a-z0-9._%+-]{2,}\s*(?:\(at\)|\[at\]|\{at\}|\yat\y|@)\s*[a-z0-9-]{2,}\s*(?:\(dot\)|\[dot\]|\{dot\}|\ydot\y|\.)\s*(?:com|net|org|me|io|co|sy|edu|info)\y)');
  end if;
  if m is not null then
    hits := hits || jsonb_build_array(jsonb_build_object('kind', 'email', 'matched', m, 'sure', true));
  end if;

  -- @handles ("my insta is @ahmad_99")
  m := substring(lb from '(?:^|[^a-z0-9._%+@-])(@[a-z0-9_][a-z0-9_.]{2,29})');
  if m is not null and m ~ '[a-z]' then
    hits := hits || jsonb_build_array(jsonb_build_object('kind', 'handle', 'matched', m, 'sure', true));
  end if;

  -- links to messaging apps, social profiles and outside meeting rooms
  m := substring(lb from '((?:wa\.me|chat\.whatsapp\.com|api\.whatsapp\.com|whatsapp\.com/|t\.me/|telegram\.me|telegram\.org/|instagram\.com|instagr\.am|snapchat\.com|facebook\.com|fb\.com|fb\.me|m\.me/|tiktok\.com|zoom\.us|zoom\.com/j|linkedin\.com|lnkd\.in|discord\.gg|discord\.com|discordapp\.com|skype\.com|skype:|signal\.me|signal\.group|viber\.com|vb\.me|line\.me|twitter\.com|threads\.net|meet\.google\.com|teams\.microsoft\.com)\S*)');
  if m is not null then
    hits := hits || jsonb_build_array(jsonb_build_object('kind', 'link', 'matched', m, 'sure', true));
  end if;

  -- asking for / offering contact outside Dars (not hidden, only flagged). "signal" alone is not an alarm.
  if jsonb_array_length(hits) = 0 then
    m := substring(lb from '(whats\s?app|واتس|وتساب|واتساب|تلغرام|تليغرام|تيليجرام|تلجرام|telegram|viber|فايبر|(?:on|via|my|your|the) signal app|(?:على|ع) (?:السيجنال|سيجنال)|instagram|\yinsta\y|انستا|إنستا|انستغرام|سناب|snapchat|فيسبوك|فيس بوك|facebook|ماسنجر|messenger|tik\s?tok|تيك\s?توك|تيكتوك|linked\s?in|لينكد|discord|ديسكورد|skype|سكايب|zoom (?:link|meeting|id)|رابط (?:ال)?زوم|على (?:ال)?زوم|رقمك|هذا رقمي|خذ رقمي|رقمي هو|على رقمي|رقم\s*(?:ال)?(?:موبايل|جوال|تلفون|تليفون|هاتف|واتس|التواصل)|موبايلك|جوالك|تلفونك|تليفونك|هاتفك|ايميلك|إيميلك|بريدك|حسابك|your (?:phone|number|mobile|whatsapp|email|insta|account)|my (?:phone|number|mobile|whatsapp|email|insta)|phone number|call me|text me|contact me|add me)');
    if m is not null then
      hits := hits || jsonb_build_array(jsonb_build_object('kind', 'contact_request', 'matched', m, 'sure', false));
    end if;
  end if;
  return hits;
end $$;

-- True if the text must be hidden (a sure phone / e-mail / handle / link).
create or replace function contact_hidden(p_body text) returns boolean
language sql immutable parallel safe set search_path = public as $$
  select exists (select 1 from jsonb_array_elements(contact_hits(p_body)) e where (e->>'sure')::boolean);
$$;

-- Hides only the contact details inside a text (live-help questions, review comments); everything else stays.
-- If a number is hidden in words or look-alike letters, the whole text is hidden.
create or replace function mask_contacts(p_body text) returns text
language plpgsql immutable parallel safe set search_path = public as $$
declare b text; r text;
begin
  if p_body is null then return null; end if;
  if not contact_hidden(p_body) then return p_body; end if;
  b := contact_light(p_body);
  for r in select (regexp_matches(b, '\+?\d(?:[\s().,*/_+-]*\d)*', 'g'))[1] loop
    if contact_phone_run(contact_digits(r)) = 'sure' then b := replace(b, btrim(r), '•••'); end if;
  end loop;
  b := regexp_replace(b, '[a-z0-9._%+-]+\s*@\s*[a-z0-9.-]+\s*\.\s*[a-z]{2,}', '•••', 'gi');
  b := regexp_replace(b, '[a-z0-9._%+-]{2,}\s*(\(at\)|\[at\]|\{at\}|\yat\y)\s*[a-z0-9-]{2,}\s*(\(dot\)|\[dot\]|\{dot\}|\ydot\y|\.)\s*[a-z]{2,4}\y', '•••', 'gi');
  b := regexp_replace(b, '(^|[^a-z0-9._%+@-])@[a-z0-9_][a-z0-9_.]{2,29}', '\1•••', 'gi');
  b := regexp_replace(b, '(wa\.me|chat\.whatsapp\.com|api\.whatsapp\.com|whatsapp\.com/|t\.me/|telegram\.me|telegram\.org/|instagram\.com|instagr\.am|snapchat\.com|facebook\.com|fb\.com|fb\.me|m\.me/|tiktok\.com|zoom\.us|zoom\.com/j|linkedin\.com|lnkd\.in|discord\.gg|discord\.com|discordapp\.com|skype\.com|skype:|signal\.me|signal\.group|viber\.com|vb\.me|line\.me|twitter\.com|threads\.net|meet\.google\.com|teams\.microsoft\.com)\S*', '•••', 'gi');
  b := regexp_replace(b, 'https?://•••', '•••', 'gi');
  if contact_hidden(b) then return '•••'; end if;
  return b;
end $$;

-- The sender's text messages of the last 2 minutes in this chat (at most 5), oldest first: a number split
-- over several messages ("0933" … "123" … "456") is checked as one.
create or replace function contact_recent_text(p_conv uuid, p_sender uuid, p_exclude bigint) returns text
language sql stable security definer set search_path = public as $$
  select string_agg(body, ' ' order by created_at, id) from (
    select body, created_at, id from messages
    where conversation_id = p_conv and sender_id = p_sender and kind = 'text' and id <> coalesce(p_exclude, -1)
      and created_at > now() - interval '2 minutes'
    order by created_at desc, id desc limit 5) x;
$$;
revoke execute on function contact_recent_text(uuid, uuid, bigint) from public, anon, authenticated;

-- Flags can now also point at a tutor profile, a review or a lesson link; two new kinds.
alter table message_flags add column if not exists source text;
alter table message_flags add column if not exists source_id text;
alter table message_flags drop constraint if exists message_flags_kind_check;
alter table message_flags add constraint message_flags_kind_check
  check (kind in ('phone', 'email', 'link', 'contact_request', 'handle', 'possible'));
alter table message_flags drop constraint if exists message_flags_target;
alter table message_flags add constraint message_flags_target
  check (message_id is not null or live_request_id is not null or source is not null);

-- Records the hits of one text and tells the admins (internal helper).
create or replace function flag_contact_hits(p_hits jsonb, p_sender uuid, p_excerpt text, p_message bigint, p_conv uuid,
                                             p_live uuid, p_source text, p_source_id text, p_where text)
returns int language plpgsql security definer set search_path = public as $$
declare e jsonb; n int := 0; who text; a uuid;
begin
  for e in select * from jsonb_array_elements(coalesce(p_hits, '[]')) loop
    insert into message_flags (message_id, conversation_id, live_request_id, source, source_id, sender_id, kind, matched, excerpt)
    values (p_message, p_conv, p_live, p_source, p_source_id, p_sender, e->>'kind', left(coalesce(e->>'matched', ''), 200),
            left(coalesce(p_excerpt, ''), 500));
    n := n + 1;
  end loop;
  if n > 0 then
    if p_conv is not null then update conversations set flagged = true where id = p_conv; end if;
    select coalesce(nullif(full_name, ''), 'User') into who from profiles where id = p_sender;
    for a in select id from profiles where role = 'admin' and status = 'active' loop
      perform push_notification(a, 'Security alert', who || ' shared or asked for contact details ' || p_where || '.',
        jsonb_strip_nulls(jsonb_build_object('security_flag', true, 'conversation_id', p_conv, 'message_id', p_message,
                                             'live_request_id', p_live, 'source', p_source, 'source_id', p_source_id)));
    end loop;
  end if;
  return n;
end $$;
revoke execute on function flag_contact_hits(jsonb, uuid, text, bigint, uuid, uuid, text, text, text) from public, anon, authenticated;

-- Hits found only when the sender's last messages are read together with this one (a split number).
create or replace function contact_split_hits(p_conv uuid, p_sender uuid, p_id bigint, p_body text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare prev text; h jsonb;
begin
  prev := contact_recent_text(p_conv, p_sender, p_id);
  if prev is null or prev !~ '[0-9٠-٩۰-۹a-z]' then return '[]'; end if;
  if contact_hidden(prev) then return '[]'; end if;     -- already hidden and flagged with that message
  h := contact_hits(prev || ' ' || p_body);
  return h;
end $$;
revoke execute on function contact_split_hits(uuid, uuid, bigint, text) from public, anon, authenticated;

-- Before a message is saved: hide it from the other person if it (or it with the sender's last messages)
-- contains contact details. Calls and files are unchanged (#3 / retest rules).
create or replace function filter_message() returns trigger
language plpgsql security definer set search_path = public as $$
declare split jsonb;
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
      new.body := case
        when new.kind = 'voice' then '🎤'
        when new.kind = 'image' then '📷'
        when new.file_url ~* '\.(mp4|mov|m4v|webm|3gp|mkv)$' then '🎬'
        else '📎' end;
    else
      new.file_url := null;
      if contact_hidden(new.body) then
        new.blocked := true;
      else
        split := contact_split_hits(new.conversation_id, new.sender_id, new.id, new.body);
        if exists (select 1 from jsonb_array_elements(split) e where (e->>'sure')::boolean) then
          new.blocked := true;
          -- the earlier pieces of the number are hidden too
          update messages set blocked = true
          where id in (select id from messages
                       where conversation_id = new.conversation_id and sender_id = new.sender_id and kind = 'text'
                         and created_at > now() - interval '2 minutes'
                       order by created_at desc, id desc limit 5)
            and contact_digits(body) ~ '\d';
        end if;
      end if;
    end if;
  end if;
  update conversations set last_message_at = now() where id = new.conversation_id;
  return new;
end $$;

-- After a message is saved: record every hit (also unsure ones) and tell the admins.
create or replace function flag_message() returns trigger
language plpgsql security definer set search_path = public as $$
declare h jsonb;
begin
  if new.kind <> 'text' or new.sender_id is null then return null; end if;
  h := contact_hits(new.body);
  if jsonb_array_length(h) = 0 then
    h := contact_split_hits(new.conversation_id, new.sender_id, new.id, new.body);
  end if;
  perform flag_contact_hits(h, new.sender_id, new.body, new.id, new.conversation_id, null, 'message', new.id::text, 'in a chat');
  return null;
end $$;

-- Live-help questions: same rules (only real contact details are masked).
create or replace function flag_live_request_internal(p_request uuid, p_student uuid, p_body text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform flag_contact_hits(contact_hits(p_body), p_student, p_body, null, null, p_request, 'live_request', p_request::text,
                            'in a live-help question');
end $$;
revoke execute on function flag_live_request_internal(uuid, uuid, text) from public, anon, authenticated;

-- Tutor headline and about: contact details are refused (the tutor sees why); unsure cases are flagged.
create or replace function check_tutor_text() returns trigger
language plpgsql security definer set search_path = public as $$
declare t text; h jsonb;
begin
  if tg_op = 'UPDATE' and new.headline is not distinct from old.headline and new.about is not distinct from old.about then
    return new;
  end if;
  t := coalesce(new.headline, '') || E'\n' || coalesce(new.about, '');
  h := contact_hits(t);
  if exists (select 1 from jsonb_array_elements(h) e where (e->>'sure')::boolean) then
    raise exception 'Contact details (phone, email, social accounts or links) are not allowed in your profile';
  end if;
  if jsonb_array_length(h) > 0 then
    perform flag_contact_hits(h, new.user_id, t, null, null, null, 'tutor_profile', new.user_id::text, 'in a tutor profile');
  end if;
  return new;
end $$;
drop trigger if exists tutor_profiles_contact on tutor_profiles;
create trigger tutor_profiles_contact before insert or update of headline, about on tutor_profiles
  for each row execute function check_tutor_text();

-- Review comments: contact details are masked and flagged.
create or replace function check_review_text() returns trigger
language plpgsql security definer set search_path = public as $$
declare h jsonb;
begin
  if new.comment is null or (tg_op = 'UPDATE' and new.comment is not distinct from old.comment) then return new; end if;
  h := contact_hits(new.comment);
  if jsonb_array_length(h) > 0 then
    perform flag_contact_hits(h, new.student_id, new.comment, null, null, null, 'review', new.lesson_id::text, 'in a review');
    new.comment := mask_contacts(new.comment);
  end if;
  return new;
end $$;
drop trigger if exists reviews_contact on reviews;
create trigger reviews_contact before insert or update of comment on reviews for each row execute function check_review_text();

-- Lesson links: a link to WhatsApp / Telegram / a phone number is refused (a refused change reaches nobody,
-- so there is nothing to flag; unsure links are saved and flagged).
create or replace function check_lesson_link() returns trigger
language plpgsql security definer set search_path = public as $$
declare h jsonb;
begin
  if new.meeting_url is null or (tg_op = 'UPDATE' and new.meeting_url is not distinct from old.meeting_url) then return new; end if;
  h := contact_hits(new.meeting_url);
  if exists (select 1 from jsonb_array_elements(h) e where (e->>'sure')::boolean) then
    raise exception 'This link is not allowed. Use the Dars classroom or a meeting link without contact details';
  end if;
  if jsonb_array_length(h) > 0 then
    perform flag_contact_hits(h, new.tutor_id, new.meeting_url, null, null, null, 'lesson_link', new.id::text, 'in a lesson link');
  end if;
  return new;
end $$;
drop trigger if exists lessons_link_contact on lessons;
create trigger lessons_link_contact before insert or update of meeting_url on lessons for each row execute function check_lesson_link();

-- Admin view: flags on chat messages, live-help questions, tutor profiles, reviews and lesson links.
drop view if exists admin_message_flags;
create view admin_message_flags with (security_invoker = true) as
select f.*,
       s.full_name as sender_name, s.role as sender_role, s.phone as sender_phone,
       coalesce(c.student_id, lr.student_id) as student_id, st.full_name as student_name, st.role as student_role,
       c.tutor_id, tu.full_name as tutor_name,
       coalesce(m.body, lr.body, f.excerpt) as message_body, coalesce(m.created_at, lr.created_at, f.created_at) as message_at,
       m.blocked as message_hidden
from message_flags f
left join conversations c on c.id = f.conversation_id
left join messages m on m.id = f.message_id
left join live_requests lr on lr.id = f.live_request_id
left join profiles s on s.id = f.sender_id
left join profiles st on st.id = coalesce(c.student_id, lr.student_id)
left join profiles tu on tu.id = c.tutor_id;

-- ── E2. Real tutor verification ────────────────────────────────────────────────────────────────────────

-- Documents a tutor uploads to the private "tutor-docs" bucket (only the tutor and admins can open them).
create table if not exists tutor_documents (
  id         uuid primary key default gen_random_uuid(),
  tutor_id   uuid not null references tutor_profiles(user_id) on delete cascade,
  kind       text not null check (kind in ('id', 'certificate', 'cv', 'other')),
  file_path  text not null unique check (file_path ~ '^tutor-docs/[0-9a-f-]{36}/[A-Za-z0-9._-]{1,80}$'),
  created_at timestamptz not null default now()
);
create index if not exists tutor_documents_tutor on tutor_documents (tutor_id, created_at);
alter table tutor_documents enable row level security;
revoke all on tutor_documents from public, anon, authenticated;
grant select on tutor_documents to authenticated;
drop policy if exists own_or_admin_read on tutor_documents;
create policy own_or_admin_read on tutor_documents for select to authenticated
  using (tutor_id = (select auth.uid()) or (select is_admin()));

-- The tutor records a file he uploaded to tutor-docs/<his id>/… (at most 10 documents).
create or replace function add_tutor_document(p_kind text, p_path text) returns uuid
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := auth.uid(); v uuid;
begin
  if u is null or not is_active_user() or not exists (select 1 from tutor_profiles where user_id = u) then
    raise exception 'Tutors only' using errcode = '42501';
  end if;
  if p_kind not in ('id', 'certificate', 'cv', 'other') then raise exception 'Unknown document type'; end if;
  if coalesce(p_path, '') !~ ('^tutor-docs/' || u::text || '/[A-Za-z0-9._-]{1,80}$') then
    raise exception 'Documents must be uploaded from the Dars app';
  end if;
  if (select count(*) from tutor_documents where tutor_id = u) >= 10 then raise exception 'Too many documents (10 at most)'; end if;
  insert into tutor_documents (tutor_id, kind, file_path) values (u, p_kind, p_path)
  on conflict (file_path) do update set kind = excluded.kind
  returning id into v;
  return v;
end $$;
revoke execute on function add_tutor_document(text, text) from public, anon;
grant execute on function add_tutor_document(text, text) to authenticated;

create or replace function remove_tutor_document(p_id uuid) returns void
language sql volatile security definer set search_path = public as $$
  delete from tutor_documents where id = p_id and tutor_id = auth.uid();
$$;
revoke execute on function remove_tutor_document(uuid) from public, anon;
grant execute on function remove_tutor_document(uuid) to authenticated;

-- Code of conduct accepted at registration, and "send my application" (also after a rejection).
alter table tutor_profiles add column if not exists conduct_accepted_at timestamptz;
alter table tutor_profiles add column if not exists submitted_at timestamptz;

create or replace function submit_tutor_application(p_accept_conduct boolean) returns void
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := auth.uid(); t tutor_profiles%rowtype; who text; a uuid;
begin
  select * into t from tutor_profiles where user_id = u for update;
  if not found or not is_active_user() then raise exception 'Tutors only' using errcode = '42501'; end if;
  if p_accept_conduct is distinct from true then raise exception 'Please accept the tutor code of conduct'; end if;
  if t.verification = 'approved' then
    update tutor_profiles set conduct_accepted_at = coalesce(conduct_accepted_at, now()) where user_id = u;
    return;
  end if;
  update tutor_profiles set verification = 'pending', rejection_reason = null, submitted_at = now(),
         conduct_accepted_at = now() where user_id = u;
  select coalesce(nullif(full_name, ''), 'A tutor') into who from profiles where id = u;
  for a in select id from profiles where role = 'admin' and status = 'active' loop
    perform push_notification(a, 'New tutor application', who || ' sent documents for review.', jsonb_build_object('tutor_id', u));
  end loop;
end $$;
revoke execute on function submit_tutor_application(boolean) from public, anon;
grant execute on function submit_tutor_application(boolean) to authenticated;

-- Approve / reject (a rejection needs a reason, shown to the tutor).
create or replace function admin_set_tutor_verification(p_tutor uuid, p_status verification, p_reason text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform require_admin();
  if p_status = 'rejected' and coalesce(btrim(p_reason), '') = '' then raise exception 'Write the reason for the tutor'; end if;
  update tutor_profiles set verification = p_status,
         rejection_reason = case when p_status = 'rejected' then btrim(p_reason) end,
         verified_at = case when p_status = 'approved' then coalesce(verified_at, now()) else verified_at end
  where user_id = p_tutor;
  if not found then raise exception 'Tutor not found'; end if;
  perform push_notification(p_tutor,
    case p_status when 'approved' then 'Your profile is approved' when 'rejected' then 'Your profile needs changes' else 'Profile under review' end,
    coalesce(nullif(btrim(p_reason), ''), case p_status when 'approved' then 'You can now receive bookings and live requests.' else '' end));
  perform audit('tutor_verification', p_tutor::text, jsonb_build_object('status', p_status, 'reason', p_reason));
end $$;

-- Visitors and other users no longer read tutor_profiles directly (commission, rejection reason, CV and
-- LinkedIn stay private). Public tutor cards come from public_tutors / search_tutors, which show safe columns.
drop policy if exists approved_read on tutor_profiles;
drop policy if exists own_read on tutor_profiles;
create policy own_read on tutor_profiles for select to authenticated using (user_id = (select auth.uid()));

-- Changes by an approved tutor to name, headline, about, intro video or prices wait for the admin;
-- the old values stay public meanwhile (#18). Old app versions keep working: their save is held for review.
create table if not exists tutor_pending_changes (
  tutor_id     uuid primary key references tutor_profiles(user_id) on delete cascade,
  changes      jsonb not null default '{}',
  submitted_at timestamptz not null default now()
);
alter table tutor_pending_changes enable row level security;
revoke all on tutor_pending_changes from public, anon, authenticated;
grant select on tutor_pending_changes to authenticated;
drop policy if exists own_or_admin_read on tutor_pending_changes;
create policy own_or_admin_read on tutor_pending_changes for select to authenticated
  using (tutor_id = (select auth.uid()) or (select is_admin()));

-- True for a change the approved tutor makes himself from the app (not by Dars' own functions or an admin).
-- Runs with the caller's rights on purpose: current_user is 'authenticated' only for direct app requests.
create or replace function tutor_edit_held(p_tutor uuid) returns boolean
language sql stable set search_path = public as $$
  select current_user in ('authenticated', 'anon') and p_tutor = auth.uid() and not is_admin()
     and exists (select 1 from tutor_profiles where user_id = p_tutor and verification = 'approved');
$$;

create or replace function hold_tutor_change(p_tutor uuid, p_changes jsonb) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_tutor is distinct from auth.uid() then raise exception 'Not allowed' using errcode = '42501'; end if;
  if coalesce(p_changes, '{}'::jsonb) = '{}'::jsonb then return; end if;
  insert into tutor_pending_changes as t (tutor_id, changes, submitted_at) values (p_tutor, p_changes, now())
  on conflict (tutor_id) do update
    set changes = case when (t.changes ? 'level_prices') and (p_changes ? 'level_prices')
                       then t.changes || p_changes || jsonb_build_object('level_prices', (t.changes -> 'level_prices') || (p_changes -> 'level_prices'))
                       else t.changes || p_changes end,
        submitted_at = now();
end $$;
revoke execute on function hold_tutor_change(uuid, jsonb) from public, anon;
grant execute on function hold_tutor_change(uuid, jsonb) to authenticated;   -- own changes only (checked inside)

create or replace function hold_tutor_profile_edit() returns trigger
language plpgsql set search_path = public as $$
declare c jsonb := '{}';
begin
  if not tutor_edit_held(old.user_id) then return new; end if;
  if new.headline is distinct from old.headline then c := c || jsonb_build_object('headline', new.headline); new.headline := old.headline; end if;
  if new.about is distinct from old.about then c := c || jsonb_build_object('about', new.about); new.about := old.about; end if;
  if new.video_url is distinct from old.video_url then c := c || jsonb_build_object('video_url', new.video_url); new.video_url := old.video_url; end if;
  if new.hourly_price is distinct from old.hourly_price then c := c || jsonb_build_object('hourly_price', new.hourly_price); new.hourly_price := old.hourly_price; end if;
  perform hold_tutor_change(old.user_id, c);
  return new;
end $$;
drop trigger if exists tutor_profiles_pending on tutor_profiles;
create trigger tutor_profiles_pending before update on tutor_profiles for each row execute function hold_tutor_profile_edit();

create or replace function hold_tutor_name_edit() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.full_name is distinct from old.full_name and tutor_edit_held(old.id) then
    perform hold_tutor_change(old.id, jsonb_build_object('full_name', new.full_name));
    new.full_name := old.full_name;
  end if;
  return new;
end $$;
drop trigger if exists profiles_tutor_name_pending on profiles;
create trigger profiles_tutor_name_pending before update of full_name on profiles for each row execute function hold_tutor_name_edit();

create or replace function hold_tutor_price_edit() returns trigger
language plpgsql set search_path = public as $$
declare t uuid := coalesce(new.tutor_id, old.tutor_id);
begin
  if not tutor_edit_held(t) then return coalesce(new, old); end if;
  if tg_op in ('INSERT', 'UPDATE') then
    perform hold_tutor_change(t, jsonb_build_object('level_prices', jsonb_build_object(new.level_id, new.price)));
  end if;
  return null;       -- the public price list stays as it is until the admin approves
end $$;
drop trigger if exists tutor_level_prices_pending on tutor_level_prices;
create trigger tutor_level_prices_pending before insert or update or delete on tutor_level_prices
  for each row execute function hold_tutor_price_edit();

-- What the tutor sees: his changes waiting for review (null = none).
create or replace function my_pending_tutor_changes() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('changes', changes, 'submitted_at', submitted_at) from tutor_pending_changes where tutor_id = auth.uid();
$$;
revoke execute on function my_pending_tutor_changes() from public, anon;
grant execute on function my_pending_tutor_changes() to authenticated;

-- Admin: approve (the changes go public) or reject (with a reason for the tutor).
create or replace function admin_review_tutor_changes(p_tutor uuid, p_approve boolean, p_reason text default null) returns void
language plpgsql volatile security definer set search_path = public as $$
declare c jsonb; e record;
begin
  perform require_admin();
  select changes into c from tutor_pending_changes where tutor_id = p_tutor for update;
  if not found then raise exception 'No changes waiting'; end if;
  if not p_approve and coalesce(btrim(p_reason), '') = '' then raise exception 'Write the reason for the tutor'; end if;
  if p_approve then
    update tutor_profiles set
      headline     = case when c ? 'headline' then c->>'headline' else headline end,
      about        = case when c ? 'about' then c->>'about' else about end,
      video_url    = case when c ? 'video_url' then c->>'video_url' else video_url end,
      hourly_price = case when c ? 'hourly_price' then (c->>'hourly_price')::numeric else hourly_price end
    where user_id = p_tutor;
    if c ? 'full_name' then update profiles set full_name = c->>'full_name' where id = p_tutor; end if;
    for e in select key, value from jsonb_each(coalesce(c->'level_prices', '{}')) loop
      insert into tutor_level_prices (tutor_id, level_id, price) values (p_tutor, e.key, (e.value #>> '{}')::numeric)
      on conflict (tutor_id, level_id) do update set price = excluded.price;
    end loop;
    perform push_notification(p_tutor, 'Profile changes approved', 'Your changes are now on your public profile.', jsonb_build_object('tutor_changes', 'approved'));
  else
    perform push_notification(p_tutor, 'Profile changes not approved', btrim(p_reason), jsonb_build_object('tutor_changes', 'rejected'));
  end if;
  delete from tutor_pending_changes where tutor_id = p_tutor;
  perform audit('tutor_changes', p_tutor::text, jsonb_build_object('approved', p_approve, 'changes', c, 'reason', p_reason));
end $$;
revoke execute on function admin_review_tutor_changes(uuid, boolean, text) from public, anon;
grant execute on function admin_review_tutor_changes(uuid, boolean, text) to authenticated;

-- Admin list of tutors: documents and waiting changes included.
drop view if exists admin_tutors;
create view admin_tutors with (security_invoker = true) as
select tp.*, p.full_name, p.phone, p.email, p.city, p.country, p.status as account_status, p.created_at as joined_at,
       coalesce((select array_agg(subject_id) from tutor_subjects s where s.tutor_id = tp.user_id), '{}') as subject_ids,
       p.avatar_url,
       coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'kind', d.kind, 'file_path', d.file_path, 'created_at', d.created_at)
                                  order by d.created_at)
                 from tutor_documents d where d.tutor_id = tp.user_id), '[]') as documents,
       pc.changes as pending_changes, pc.submitted_at as pending_since
from tutor_profiles tp
join profiles p on p.id = tp.user_id
left join tutor_pending_changes pc on pc.tutor_id = tp.user_id;

-- ── E3. Child safety ───────────────────────────────────────────────────────────────────────────────────
-- Owner's rule: under 13 → only as a child profile inside a parent's account; 13–17 → own account, but a
-- parent must approve it with an invite code before booking, chatting or asking for live help.
-- Age is counted from the year of birth only: someone who turns 18 this year still counts as under 18
-- until next year, and someone who turns 13 this year may sign up (safe side for the 18 limit).
-- Accounts made before Round E (or by old app versions) have no year of birth and count as adults:
-- raise min_app_build to the first Round E build so every new sign-up is asked its age.

alter table profiles add column if not exists birth_year int check (birth_year between 1900 and 2100);

create or replace function is_minor(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select extract(year from now())::int - birth_year <= 18 from profiles where id = p_user), false);
$$;

-- The year of birth is set once by the user (and only by an admin after that); under 13 is refused.
create or replace function guard_birth_year() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.birth_year is not distinct from old.birth_year then return new; end if;
  if current_user in ('authenticated', 'anon') and not is_admin() then
    if old.birth_year is not null then raise exception 'Your year of birth is already saved. Contact Dars to change it'; end if;
    if new.role in ('tutor', 'parent') and extract(year from now())::int - new.birth_year <= 18 then
      raise exception 'Tutor and parent accounts are for adults (18+)';
    end if;
    if extract(year from now())::int - new.birth_year <= 12 then
      raise exception 'Students under 13 use Dars through a parent''s account. Ask your parent to add you as a child';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists profiles_birth_year on profiles;
create trigger profiles_birth_year before update of birth_year on profiles for each row execute function guard_birth_year();

-- Parent approval of a 13–17 account: the teen gets a code, the parent types it in his own account.
create table if not exists parent_links (
  student_id  uuid primary key references profiles(id) on delete cascade,
  parent_id   uuid references profiles(id) on delete cascade,
  code        text not null unique,
  status      text not null default 'waiting' check (status in ('waiting', 'approved')),
  created_at  timestamptz not null default now(),
  approved_at timestamptz
);
create index if not exists parent_links_parent on parent_links (parent_id) where status = 'approved';
alter table parent_links enable row level security;
revoke all on parent_links from public, anon, authenticated;
grant select on parent_links to authenticated;
drop policy if exists own_read on parent_links;
create policy own_read on parent_links for select to authenticated
  using (student_id = (select auth.uid()) or parent_id = (select auth.uid()) or (select is_admin()));

-- An account under 18 without an approving parent cannot book, chat or ask for live help yet.
create or replace function needs_parent(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select is_minor(p_user) and not exists (select 1 from parent_links where student_id = p_user and status = 'approved');
$$;

-- My parent code (made on first ask). Null once a parent has approved.
create or replace function my_parent_code() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := auth.uid(); l parent_links%rowtype; c text; pname text;
begin
  if u is null or not is_active_user() then raise exception 'Not allowed' using errcode = '42501'; end if;
  if not is_minor(u) then return jsonb_build_object('needed', false); end if;
  select * into l from parent_links where student_id = u;
  if found and l.status = 'approved' then
    select full_name into pname from profiles where id = l.parent_id;
    return jsonb_build_object('needed', false, 'approved', true, 'parent_name', pname);
  end if;
  if not found then
    loop
      c := array_to_string(array(select substr('ABCDEFGHJKMNPQRSTUVWXYZ23456789', 1 + floor(random() * 31)::int, 1)
                                 from generate_series(1, 8)), '');
      begin
        insert into parent_links (student_id, code) values (u, c) returning * into l;
        exit;
      exception when unique_violation then
        if exists (select 1 from parent_links where student_id = u) then select * into l from parent_links where student_id = u; exit; end if;
      end;
    end loop;
  end if;
  return jsonb_build_object('needed', true, 'code', l.code);
end $$;
revoke execute on function my_parent_code() from public, anon;
grant execute on function my_parent_code() to authenticated;

-- The parent links his child's account with the code (parent accounts only, 18+).
create or replace function link_child_account(p_code text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := auth.uid(); l parent_links%rowtype; n text;
begin
  if u is null or not is_active_user() or (select role from profiles where id = u) <> 'parent' or is_minor(u) then
    raise exception 'Only a parent account can approve a child' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtext('parent_link:' || u::text));
  if (select count(*) from parent_links where parent_id = u and approved_at > now() - interval '1 hour') >= 5 then
    raise exception 'Too many tries. Try again later';
  end if;
  select * into l from parent_links where code = upper(btrim(coalesce(p_code, ''))) and status = 'waiting' for update;
  if not found then raise exception 'This code is not valid'; end if;
  if l.student_id = u then raise exception 'This code is not valid'; end if;
  update parent_links set parent_id = u, status = 'approved', approved_at = now() where student_id = l.student_id;
  select full_name into n from profiles where id = l.student_id;
  perform push_notification(l.student_id, 'Your parent approved your account', 'You can now book lessons and chat with tutors.',
                            jsonb_build_object('parent_link', 'approved'));
  perform audit('parent_link', l.student_id::text, jsonb_build_object('parent', u));
  return jsonb_build_object('student_id', l.student_id, 'name', n);
end $$;
revoke execute on function link_child_account(text) from public, anon;
grant execute on function link_child_account(text) to authenticated;

-- The parent removes the link (the child's account then waits for a parent again).
create or replace function unlink_child_account(p_student uuid) returns void
language plpgsql volatile security definer set search_path = public as $$
begin
  delete from parent_links where student_id = p_student and parent_id = auth.uid();
  if not found then raise exception 'Not your child'; end if;
  perform audit('parent_unlink', p_student::text, jsonb_build_object('parent', auth.uid()));
end $$;
revoke execute on function unlink_child_account(uuid) from public, anon;
grant execute on function unlink_child_account(uuid) to authenticated;

-- Children under 13 (or any child the parent books for): profiles inside the parent's account, no login.
create table if not exists child_profiles (
  id         uuid primary key default gen_random_uuid(),
  parent_id  uuid not null references profiles(id) on delete cascade,
  full_name  text not null check (char_length(btrim(full_name)) between 1 and 80),
  level_id   text references study_levels(id),
  birth_year int check (birth_year between 1990 and 2100),
  created_at timestamptz not null default now()
);
create index if not exists child_profiles_parent on child_profiles (parent_id);
alter table child_profiles enable row level security;
revoke all on child_profiles from public, anon, authenticated;
grant select on child_profiles to authenticated;
drop policy if exists own_read on child_profiles;
create policy own_read on child_profiles for select to authenticated using (parent_id = (select auth.uid()) or (select is_admin()));

create or replace function save_child_profile(p_id uuid, p_name text, p_level text default null, p_birth_year int default null) returns uuid
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := auth.uid(); v uuid;
begin
  if u is null or not is_active_user() or (select role from profiles where id = u) <> 'parent' then
    raise exception 'Only a parent account can add children' using errcode = '42501';
  end if;
  if contact_hidden(p_name) then raise exception 'Contact details are not allowed in a name'; end if;
  if p_id is null then
    if (select count(*) from child_profiles where parent_id = u) >= 10 then raise exception 'Up to 10 children'; end if;
    insert into child_profiles (parent_id, full_name, level_id, birth_year) values (u, btrim(p_name), p_level, p_birth_year) returning id into v;
  else
    update child_profiles set full_name = btrim(p_name), level_id = p_level, birth_year = p_birth_year
    where id = p_id and parent_id = u returning id into v;
    if v is null then raise exception 'Not your child'; end if;
  end if;
  return v;
end $$;
revoke execute on function save_child_profile(uuid, text, text, int) from public, anon;
grant execute on function save_child_profile(uuid, text, text, int) to authenticated;

create or replace function remove_child_profile(p_id uuid) returns void
language sql volatile security definer set search_path = public as $$
  delete from child_profiles where id = p_id and parent_id = auth.uid();
$$;
revoke execute on function remove_child_profile(uuid) from public, anon;
grant execute on function remove_child_profile(uuid) to authenticated;

-- Lessons booked by a parent for a child keep the child's name (shown to the tutor).
alter table lessons add column if not exists child_id uuid references child_profiles(id) on delete set null;
alter table lessons add column if not exists child_name text;

create or replace function book_lesson_for_child(
  p_child uuid, p_tutor uuid, p_starts_at timestamptz, p_duration int,
  p_subject text default null, p_level text default null,
  p_mode lesson_mode default 'online', p_notes text default null,
  p_use_wallet boolean default true, p_method payment_method default 'card')
returns jsonb language plpgsql security definer set search_path = public as $$
declare c child_profiles%rowtype; r jsonb;
begin
  select * into c from child_profiles where id = p_child and parent_id = me();
  if not found then raise exception 'Not your child'; end if;
  r := book_lesson(p_tutor, p_starts_at, p_duration, p_subject, coalesce(p_level, c.level_id), p_mode, p_notes, p_use_wallet, p_method);
  update lessons set child_id = c.id, child_name = c.full_name where id = (r->>'lesson_id')::uuid;
  return r || jsonb_build_object('child_name', c.full_name);
end $$;
revoke execute on function book_lesson_for_child(uuid, uuid, timestamptz, int, text, text, lesson_mode, text, boolean, payment_method) from public, anon;
grant execute on function book_lesson_for_child(uuid, uuid, timestamptz, int, text, text, lesson_mode, text, boolean, payment_method) to authenticated;

-- Rules on new lessons, packages, live-help questions and messages from a student under 18.
create or replace function guard_minor_lesson() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if needs_parent(new.student_id) then
    raise exception 'Your parent needs to approve your account first (Account → Parent approval)';
  end if;
  if tg_table_name = 'lessons' then
    if new.mode = 'in_person' and is_minor(new.student_id) then
      raise exception 'In-person lessons for students under 18 are booked by a parent';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists lessons_minor on lessons;
create trigger lessons_minor before insert on lessons for each row execute function guard_minor_lesson();
drop trigger if exists packages_minor on packages;
create trigger packages_minor before insert on packages for each row execute function guard_minor_lesson();
drop trigger if exists live_requests_minor on live_requests;
create trigger live_requests_minor before insert on live_requests for each row execute function guard_minor_lesson();

-- ── E3. Blocking a user (chat 14) ──
create table if not exists user_blocks (
  blocker_id uuid not null references profiles(id) on delete cascade,
  blocked_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index if not exists user_blocks_blocked on user_blocks (blocked_id);
alter table user_blocks enable row level security;
revoke all on user_blocks from public, anon, authenticated;
grant select on user_blocks to authenticated;
drop policy if exists own_read on user_blocks;
create policy own_read on user_blocks for select to authenticated using (blocker_id = (select auth.uid()) or (select is_admin()));

create or replace function blocked_between(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from user_blocks where (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a));
$$;

-- Block / unblock the other person of a chat (only people I have a chat or lesson with).
create or replace function block_user(p_user uuid) returns void
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := auth.uid();
begin
  if u is null or not is_active_user() then raise exception 'Not allowed' using errcode = '42501'; end if;
  if p_user is null or p_user = u then raise exception 'Not allowed'; end if;
  if not exists (select 1 from conversations where (student_id = u and tutor_id = p_user) or (tutor_id = u and student_id = p_user))
     and not exists (select 1 from lessons where (student_id = u and tutor_id = p_user) or (tutor_id = u and student_id = p_user)) then
    raise exception 'You can only block people you are in touch with';
  end if;
  insert into user_blocks (blocker_id, blocked_id) values (u, p_user) on conflict do nothing;
  perform audit('block_user', p_user::text, jsonb_build_object('by', u));
end $$;
revoke execute on function block_user(uuid) from public, anon;
grant execute on function block_user(uuid) to authenticated;

create or replace function unblock_user(p_user uuid) returns void
language sql volatile security definer set search_path = public as $$
  delete from user_blocks where blocker_id = auth.uid() and blocked_id = p_user;
$$;
revoke execute on function unblock_user(uuid) from public, anon;
grant execute on function unblock_user(uuid) to authenticated;

-- Messages and calls: refused between blocked people, and from a student under 18 waiting for a parent.
create or replace function guard_message_people() returns trigger
language plpgsql security definer set search_path = public as $$
declare c conversations%rowtype; other uuid;
begin
  if new.sender_id is null then return new; end if;
  select * into c from conversations where id = new.conversation_id;
  other := case when c.student_id = new.sender_id then c.tutor_id else c.student_id end;
  if blocked_between(new.sender_id, other) then
    raise exception 'You cannot message or call this person (blocked)';
  end if;
  if new.sender_id = c.student_id and needs_parent(new.sender_id) then
    raise exception 'Your parent needs to approve your account first (Account → Parent approval)';
  end if;
  return new;
end $$;
drop trigger if exists messages_people on messages;
create trigger messages_people before insert on messages for each row execute function guard_message_people();

-- ── E3. Lesson attendance log (join / leave times of both sides, written by the app) ──
create table if not exists lesson_attendance (
  id        bigint generated always as identity primary key,
  lesson_id uuid not null references lessons(id) on delete cascade,
  user_id   uuid not null references profiles(id) on delete cascade,
  event     text not null check (event in ('join', 'leave')),
  at        timestamptz not null default now()
);
create index if not exists lesson_attendance_lesson on lesson_attendance (lesson_id, at);
alter table lesson_attendance enable row level security;
revoke all on lesson_attendance from public, anon, authenticated;
grant select on lesson_attendance to authenticated;
drop policy if exists admin_read on lesson_attendance;
create policy admin_read on lesson_attendance for select to authenticated using ((select is_admin()));

create or replace function log_lesson_attendance(p_lesson uuid, p_event text) returns void
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := auth.uid(); l lessons%rowtype;
begin
  if not is_active_user() then raise exception 'Not allowed' using errcode = '42501'; end if;
  if p_event not in ('join', 'leave') then raise exception 'Unknown event'; end if;
  select * into l from lessons where id = p_lesson;
  if not found or u is null or u not in (l.student_id, l.tutor_id) then raise exception 'Lesson not found'; end if;
  if now() < l.starts_at - interval '1 hour' or now() > l.starts_at + make_interval(mins => l.duration_min) + interval '6 hours' then
    return;      -- outside the lesson's day window: not recorded
  end if;
  if (select count(*) from lesson_attendance where lesson_id = p_lesson and user_id = u) >= 200 then return; end if;
  insert into lesson_attendance (lesson_id, user_id, event) values (p_lesson, u, p_event);
end $$;
revoke execute on function log_lesson_attendance(uuid, text) from public, anon;
grant execute on function log_lesson_attendance(uuid, text) to authenticated;

-- Admin: lessons with names, the child, and the attendance log (who joined / left when).
drop view if exists admin_lessons;
create view admin_lessons with (security_invoker = true) as
select l.*, s.full_name as student_name, s.phone as student_phone, t.full_name as tutor_name,
       coalesce((select jsonb_agg(jsonb_build_object('who', case when a.user_id = l.tutor_id then 'tutor' else 'student' end,
                                                     'event', a.event, 'at', a.at) order by a.at)
                 from lesson_attendance a where a.lesson_id = l.id), '[]') as attendance
from lessons l
join profiles s on s.id = l.student_id
join profiles t on t.id = l.tutor_id;

-- ── E3. Parent's read-only view of each child ──
-- My children: linked accounts (13–17) and child profiles.
create or replace function my_children() returns jsonb
language sql stable security definer set search_path = public as $$
  select case when not is_active_user() then null else jsonb_build_object(
    'accounts', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'name', p.full_name, 'birth_year', p.birth_year,
                                                               'level_id', p.level_id, 'linked_at', pl.approved_at) order by pl.approved_at)
                          from parent_links pl join profiles p on p.id = pl.student_id
                          where pl.parent_id = auth.uid() and pl.status = 'approved'), '[]'),
    'profiles', coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'name', c.full_name, 'level_id', c.level_id,
                                                               'birth_year', c.birth_year) order by c.created_at)
                          from child_profiles c where c.parent_id = auth.uid()), '[]')) end;
$$;
revoke execute on function my_children() from public, anon;
grant execute on function my_children() to authenticated;

-- One child's lessons, tutors and chats (read-only). p_child = a linked account or a child profile.
create or replace function child_activity(p_child uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare u uuid := auth.uid(); acc boolean; prof boolean;
begin
  if not is_active_user() then raise exception 'Not allowed' using errcode = '42501'; end if;
  acc := exists (select 1 from parent_links where student_id = p_child and parent_id = u and status = 'approved');
  prof := exists (select 1 from child_profiles where id = p_child and parent_id = u);
  if not acc and not prof then raise exception 'Not your child' using errcode = '42501'; end if;
  return jsonb_build_object(
    'lessons', coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'number', l.number, 'tutor_id', l.tutor_id, 'tutor_name', t.full_name,
                                                              'subject_id', l.subject_id, 'starts_at', l.starts_at, 'duration_min', l.duration_min,
                                                              'mode', l.mode, 'status', l.status) order by l.starts_at desc)
                         from (select * from lessons where (acc and student_id = p_child) or (prof and child_id = p_child)
                               order by starts_at desc limit 100) l
                         join profiles t on t.id = l.tutor_id), '[]'),
    'chats', case when acc then coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'tutor_id', c.tutor_id, 'tutor_name', t.full_name,
                                                                              'last_message_at', c.last_message_at) order by c.last_message_at desc)
                                          from conversations c join profiles t on t.id = c.tutor_id where c.student_id = p_child), '[]')
                  else '[]'::jsonb end);
end $$;
revoke execute on function child_activity(uuid) from public, anon;
grant execute on function child_activity(uuid) to authenticated;

-- Messages of a linked child's chat (read-only, newest first, 50 at a time).
create or replace function child_chat_messages(p_conversation uuid, p_before timestamptz default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare c conversations%rowtype;
begin
  if not is_active_user() then raise exception 'Not allowed' using errcode = '42501'; end if;
  select * into c from conversations where id = p_conversation;
  if not found or not exists (select 1 from parent_links where student_id = c.student_id and parent_id = auth.uid() and status = 'approved') then
    raise exception 'Not your child' using errcode = '42501';
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'from_child', m.sender_id = c.student_id, 'kind', m.kind,
                                                       'body', m.body, 'blocked', m.blocked, 'created_at', m.created_at) order by m.created_at desc, m.id desc)
                   from (select * from messages where conversation_id = p_conversation
                           and (p_before is null or created_at < p_before)
                         order by created_at desc, id desc limit 50) m), '[]');
end $$;
revoke execute on function child_chat_messages(uuid, timestamptz) from public, anon;
grant execute on function child_chat_messages(uuid, timestamptz) to authenticated;

-- ── E4. Terms / privacy consent and account deletion ──────────────────────────────────────────────────

-- Consent: the version of the Terms & Privacy each user accepted (raise "terms_version" in admin Settings
-- after changing the texts, and everyone is asked again).
insert into app_settings (key, value) values ('terms_version', '1') on conflict (key) do nothing;
alter table profiles add column if not exists terms_version int;
alter table profiles add column if not exists terms_accepted_at timestamptz;

create or replace function accept_terms(p_version int) returns void
language plpgsql volatile security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Not allowed' using errcode = '42501'; end if;
  if p_version is null or p_version < 1 or p_version > coalesce(setting_num('terms_version')::int, 1) then raise exception 'Unknown version'; end if;
  update profiles set terms_version = p_version, terms_accepted_at = now() where id = auth.uid();
end $$;
revoke execute on function accept_terms(int) from public, anon;
grant execute on function accept_terms(int) to authenticated;

-- Account deletion: the user asks, is signed out, and 14 days later the account is anonymised
-- (lessons and payments stay for the accounts, without name, phone, e-mail, photo or chat text).
-- Signing in again within the 14 days and choosing "keep my account" cancels it.
create table if not exists account_deletions (
  user_id      uuid primary key references profiles(id) on delete cascade,
  requested_at timestamptz not null default now(),
  delete_after timestamptz not null default now() + interval '14 days',
  status       text not null default 'waiting' check (status in ('waiting', 'done', 'cancelled')),
  done_at      timestamptz,
  done_by      uuid references profiles(id)
);
create index if not exists account_deletions_due on account_deletions (delete_after) where status = 'waiting';
alter table account_deletions enable row level security;
revoke all on account_deletions from public, anon, authenticated;
grant select on account_deletions to authenticated;
drop policy if exists own_or_admin_read on account_deletions;
create policy own_or_admin_read on account_deletions for select to authenticated
  using (user_id = (select auth.uid()) or (select is_admin()));

-- What the app needs at start: the Terms version to accept, and a deletion waiting (if any).
create or replace function terms_status() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('version', coalesce(setting_num('terms_version')::int, 1),
                            'accepted', coalesce(p.terms_version, 0) >= coalesce(setting_num('terms_version')::int, 1),
                            'deletion', (select jsonb_build_object('requested_at', d.requested_at, 'delete_after', d.delete_after)
                                         from account_deletions d where d.user_id = p.id and d.status = 'waiting'))
  from profiles p where p.id = auth.uid();
$$;
revoke execute on function terms_status() from public, anon;
grant execute on function terms_status() to authenticated;

create or replace function request_account_deletion() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := auth.uid(); d account_deletions%rowtype;
begin
  if u is null or not is_active_user() then raise exception 'Not allowed' using errcode = '42501'; end if;
  if (select role from profiles where id = u) = 'admin' then raise exception 'Admin accounts are removed by another admin'; end if;
  if exists (select 1 from lessons where u in (student_id, tutor_id) and status in ('confirmed', 'pending_payment') and starts_at > now()) then
    raise exception 'Cancel or finish your upcoming lessons first';
  end if;
  insert into account_deletions (user_id) values (u)
  on conflict (user_id) do update set requested_at = now(), delete_after = now() + interval '14 days', status = 'waiting', done_at = null
  returning * into d;
  delete from device_tokens where user_id = u;                            -- no more notifications
  update tutor_profiles set available_now = false where user_id = u;
  perform audit('account_deletion_requested', u::text, '{}');
  return jsonb_build_object('delete_after', d.delete_after);
end $$;
revoke execute on function request_account_deletion() from public, anon;
grant execute on function request_account_deletion() to authenticated;

create or replace function cancel_account_deletion() returns void
language plpgsql volatile security definer set search_path = public as $$
begin
  update account_deletions set status = 'cancelled' where user_id = auth.uid() and status = 'waiting';
  if not found then raise exception 'Nothing to cancel'; end if;
  perform audit('account_deletion_cancelled', auth.uid()::text, '{}');
end $$;
revoke execute on function cancel_account_deletion() from public, anon;
grant execute on function cancel_account_deletion() to authenticated;

-- Anonymise one account (internal: the daily job, or an admin's "delete now").
create or replace function anonymise_account(p_user uuid, p_by uuid) returns void
language plpgsql volatile security definer set search_path = public as $$
begin
  update profiles set full_name = 'Deleted user', phone = null, email = null, avatar_url = null, city = null, gender = null,
         birth_year = null, fcm_token = null, referred_by = null, status = 'deleted'
  where id = p_user;
  update tutor_profiles set headline = '', about = '', video_url = null, cv_url = null, linkedin_url = null,
         available_now = false, rejection_reason = null
  where user_id = p_user;
  delete from tutor_documents where tutor_id = p_user;
  delete from tutor_pending_changes where tutor_id = p_user;
  delete from device_tokens where user_id = p_user;
  delete from notification_prefs where user_id = p_user;
  delete from child_profiles where parent_id = p_user;
  delete from parent_links where student_id = p_user or parent_id = p_user;
  delete from user_blocks where blocker_id = p_user or blocked_id = p_user;
  delete from notifications where user_id = p_user;
  update messages set body = case when kind = 'call' then body else '' end, file_url = null where sender_id = p_user;
  update live_requests set body = null, voice_url = null, photo_url = null where student_id = p_user;
  update reviews set comment = null where student_id = p_user;
  update account_deletions set status = 'done', done_at = now(), done_by = p_by where user_id = p_user;
  -- the sign-in itself: no phone / e-mail left, so the number can sign up again as a new account
  begin
    update auth.users set phone = null, email = null, raw_user_meta_data = '{}'::jsonb where id = p_user;
  exception when others then null;
  end;
  perform audit('account_deleted', p_user::text, jsonb_build_object('by', p_by));
end $$;
revoke execute on function anonymise_account(uuid, uuid) from public, anon, authenticated;

-- Daily job: accounts whose 14 days have passed.
create or replace function process_account_deletions() returns int
language plpgsql volatile security definer set search_path = public as $$
declare r record; n int := 0;
begin
  for r in select user_id from account_deletions where status = 'waiting' and delete_after <= now() loop
    perform anonymise_account(r.user_id, null);
    n := n + 1;
  end loop;
  return n;
end $$;
revoke execute on function process_account_deletions() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('dars-account-deletions', '17 3 * * *', 'select public.process_account_deletions()');
  end if;
end $$;

-- Admin: delete now (after checking money), or see the queue.
create or replace function admin_delete_account_now(p_user uuid) returns void
language plpgsql volatile security definer set search_path = public as $$
begin
  perform require_admin();
  if not exists (select 1 from account_deletions where user_id = p_user and status = 'waiting') then
    raise exception 'This account did not ask to be deleted';
  end if;
  perform anonymise_account(p_user, auth.uid());
end $$;
revoke execute on function admin_delete_account_now(uuid) from public, anon;
grant execute on function admin_delete_account_now(uuid) to authenticated;

create or replace view admin_account_deletions with (security_invoker = true) as
select d.*, p.full_name, p.role, p.phone, p.email,
       wallet_balance(d.user_id) as balance,
       (select count(*) from lessons l where d.user_id in (l.student_id, l.tutor_id) and l.status in ('confirmed', 'pending_payment') and l.starts_at > now()) as upcoming_lessons,
       (select count(*) from payouts po where po.tutor_id = d.user_id and po.status in ('requested', 'approved')) as open_payouts
from account_deletions d join profiles p on p.id = d.user_id;

-- ── E5. Sign-in by phone (built, switched off) ─────────────────────────────────────────────────────────
-- The owner chose to wait with a code provider. "phone_signin" = 'off' | 'sms' | 'whatsapp':
--   'off' → the app offers e-mail + password only (no failing "send code" button);
--   after setting up SMS / WhatsApp codes in Supabase → Authentication → Providers → Phone, set it to 'sms'
--   or 'whatsapp' in admin Settings and the phone screen and "Add a phone number" appear (no new app needed).
insert into app_settings (key, value) values ('phone_signin', '"off"') on conflict (key) do nothing;

-- A phone number added to an existing (e-mail) account becomes the profile's phone too.
create or replace function sync_auth_phone() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.phone is distinct from old.phone and nullif(trim(coalesce(new.phone, '')), '') is not null then
    update profiles set phone = nullif(trim(new.phone), '') where id = new.id and phone is distinct from nullif(trim(new.phone), '');
  end if;
  return new;
end $$;
do $$
begin
  if to_regclass('auth.users') is not null then
    execute 'drop trigger if exists on_auth_phone_changed on auth.users';
    execute 'create trigger on_auth_phone_changed after update of phone on auth.users for each row execute function public.sync_auth_phone()';
  end if;
end $$;

-- ── Who may call what (Round E) ───────────────────────────────────────────────────────────────────────
-- Internal checks are not callable from outside (they would reveal ages, parent links or blocks).
revoke execute on function is_minor(uuid) from public, anon, authenticated;
revoke execute on function needs_parent(uuid) from public, anon, authenticated;
revoke execute on function blocked_between(uuid, uuid) from public, anon, authenticated;
revoke execute on function tutor_edit_held(uuid) from public, anon;
grant execute on function tutor_edit_held(uuid) to authenticated;   -- used by the held-edit triggers in the tutor's own request

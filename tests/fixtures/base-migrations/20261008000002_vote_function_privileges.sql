-- Supabase default privileges can explicitly grant EXECUTE to anon.
-- Revoke that role directly, in addition to PUBLIC; authenticated access stays intact.
revoke all on function public.toggle_rant_vote(uuid,smallint) from public, anon;

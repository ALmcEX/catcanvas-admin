begin;
alter table public.profiles add column if not exists is_superadmin boolean not null default false;

-- An own-row RLS policy does not prevent changing a privileged column.
-- Only the trusted database owner/service role can bootstrap or revoke admins.
create or replace function public.protect_admin_flag() returns trigger
language plpgsql set search_path='' as $$
begin
 if current_user not in ('postgres','supabase_admin','service_role') then
  if (TG_OP='INSERT' and new.is_superadmin) or
     (TG_OP='UPDATE' and new.is_superadmin is distinct from old.is_superadmin) then
   raise exception 'administrator flag is managed by the database owner' using errcode='42501';
  end if;
 end if;
 return new;
end $$;
create trigger protect_admin_flag before insert or update on public.profiles
for each row execute function public.protect_admin_flag();
revoke all on function public.protect_admin_flag() from public,anon,authenticated;

create function public.is_superadmin() returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select p.is_superadmin from public.profiles p
 where p.id=auth.uid()
 and auth.jwt()->'app_metadata'->>'provider'='google'
 and exists(select 1 from jsonb_array_elements(coalesce(auth.jwt()->'amr','[]'::jsonb)) a where a->>'method'='oauth')
 and not exists(select 1 from auth.identities i where i.user_id=p.id and i.provider<>'google')
 and exists(select 1 from auth.identities i where i.user_id=p.id and i.provider='google')),false)
$$;
revoke all on function public.is_superadmin() from public,anon;
grant execute on function public.is_superadmin() to authenticated;

create function public.require_superadmin() returns void
language plpgsql stable security definer set search_path='' as $$
begin
 if not public.is_superadmin() then raise exception 'superadmin required' using errcode='42501'; end if;
end $$;
revoke all on function public.require_superadmin() from public,anon;
grant execute on function public.require_superadmin() to authenticated;

create function public.admin_overview() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 perform public.require_superadmin();
 select jsonb_build_object(
 'users',(select count(*) from public.profiles),
 'generations',(select count(*) from public.ai_generations where user_id is not null),
 'published',(select count(*) from public.rants where generation_id is not null and not is_example),
 'votes',(select count(*) from public.rant_votes),
 'upvotes',(select count(*) from public.rant_votes where value=1),
 'downvotes',(select count(*) from public.rant_votes where value=-1),
 'images',(select count(*) from public.ai_generations where media_type='image'),
 'captions',(select count(*) from public.ai_generations where purpose='meme_caption'),
 'activity',(select jsonb_agg(jsonb_build_object('day',d::date,'generations',(select count(*) from public.ai_generations g where g.user_id is not null and (g.created_at at time zone 'America/New_York')::date=d::date),'votes',(select count(*) from public.rant_votes v where (v.created_at at time zone 'America/New_York')::date=d::date)) order by d)
 from generate_series((now() at time zone 'America/New_York')::date-13,(now() at time zone 'America/New_York')::date,interval '1 day') d),
 'leaders',(select coalesce(jsonb_agg(x),'[]') from (select r.id,r.title,count(*) as votes,count(*) filter(where v.value=1) as upvotes,count(*) filter(where v.value=-1) as downvotes from public.rants r join public.rant_votes v on v.rant_id=r.id group by r.id order by count(*) desc,r.created_at desc limit 5) x),
 'divisive',(select coalesce(jsonb_agg(x),'[]') from (select r.id,r.title,count(*) as votes,round(100.0*least(count(*) filter(where v.value=1),count(*) filter(where v.value=-1))/count(*),1) as disagreement from public.rants r join public.rant_votes v on v.rant_id=r.id group by r.id having count(*)>=2 order by least(count(*) filter(where v.value=1),count(*) filter(where v.value=-1))::numeric/count(*) desc,count(*) desc limit 5) x)
 ) into result;
 return result;
end $$;

create function public.admin_profiles(p_query text default '',p_page integer default 0) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb; q text:=left(coalesce(p_query,''),120);
begin
 perform public.require_superadmin();
 if p_page is null or p_page<0 or p_page>10000 then raise exception 'invalid page';end if;
 select jsonb_build_object('rows',(select coalesce(jsonb_agg(x),'[]') from (
 select p.id,p.first_name,p.last_name,p.created_at,p.is_superadmin,
 (select count(*) from public.ai_generations g where g.user_id=p.id) as generations,
 (select count(*) from public.rant_votes v where v.user_id=p.id) as votes
 from public.profiles p where concat_ws(' ',p.first_name,p.last_name,p.id::text) ilike '%'||q||'%'
 order by p.created_at desc,p.id limit 20 offset p_page*20) x),
 'total',(select count(*) from public.profiles p where concat_ws(' ',p.first_name,p.last_name,p.id::text) ilike '%'||q||'%')) into result;
 return result;
end $$;

create function public.admin_media(p_query text default '',p_page integer default 0) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb; q text:=left(coalesce(p_query,''),120);
begin
 perform public.require_superadmin();
 if p_page is null or p_page<0 or p_page>10000 then raise exception 'invalid page';end if;
 select jsonb_build_object('rows',(select coalesce(jsonb_agg(x),'[]') from (
 select g.id,g.user_id,g.media_type,g.purpose,g.created_at,g.model,g.prompt,g.image_path,g.meme_template,g.caption_choices,g.selected_caption,g.body as generated_body,
 r.id as post_id,coalesce(r.title,g.title) as title,coalesce(r.body,g.body) as body,coalesce(r.location,'') as location,
 (select count(*) from public.rant_votes v where v.rant_id=r.id) as votes,
 (select count(*) from public.rant_comments c where c.rant_id=r.id) as comments
 from public.ai_generations g left join public.rants r on r.generation_id=g.id
 where g.user_id is not null and concat_ws(' ',g.title,g.prompt,g.id::text,r.title) ilike '%'||q||'%'
 order by g.created_at desc,g.id limit 20 offset p_page*20) x),
 'total',(select count(*) from public.ai_generations g left join public.rants r on r.generation_id=g.id where g.user_id is not null and concat_ws(' ',g.title,g.prompt,g.id::text,r.title) ilike '%'||q||'%')) into result;
 return result;
end $$;

create function public.admin_votes(p_page integer default 0) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 perform public.require_superadmin();
 if p_page is null or p_page<0 or p_page>10000 then raise exception 'invalid page';end if;
 select jsonb_build_object('rows',(select coalesce(jsonb_agg(x),'[]') from (
 select v.id,v.user_id,v.value,v.created_at,v.rant_id,r.title,concat_ws(' ',p.first_name,p.last_name) as voter
 from public.rant_votes v join public.rants r on r.id=v.rant_id left join public.profiles p on p.id=v.user_id
 order by v.created_at desc,v.id limit 20 offset p_page*20) x),'total',(select count(*) from public.rant_votes)) into result;
 return result;
end $$;

-- Keep the original owner and canonical provenance checks, extending only the owner condition.
create or replace function public.validate_rant_references() returns trigger language plpgsql security definer set search_path='' as $$
declare g public.ai_generations; admin boolean:=false;
begin
 if auth.role() in ('anon','authenticated') then
  if auth.role()='authenticated' then admin:=public.is_superadmin(); end if;
  if (not admin and new.user_id is distinct from auth.uid()) or new.is_example then raise exception 'invalid owner'; end if;
  if new.generation_id is not null then
   select * into g from public.ai_generations where id=new.generation_id and user_id=new.user_id;
   if not found then raise exception 'invalid generation'; end if;
   if g.purpose='meme_caption' then
    if new.body is distinct from g.body or new.image_path is not null then raise exception 'invalid caption'; end if;
    new.meme_template:=g.meme_template; new.meme_scene:=g.prompt; new.ai_image_path:=null;
   else
    if new.meme_template is not null or new.meme_scene is not null then raise exception 'invalid meme'; end if;
    if g.media_type='image' then
     if not exists(select 1 from storage.objects o where o.bucket_id='ai-cat-images' and o.name=g.image_path and (storage.foldername(o.name))[1]=new.user_id::text) then raise exception 'invalid generated image'; end if;
     new.ai_image_path:=g.image_path;
    else new.ai_image_path:=null; end if;
   end if;
  else
   if new.meme_template is not null or new.meme_scene is not null then raise exception 'invalid meme'; end if;
   new.ai_image_path:=null;
  end if;
  if new.image_path is not null and not exists(select 1 from storage.objects o where o.bucket_id='rant-photos' and o.name=new.image_path and (storage.foldername(o.name))[1]=new.user_id::text) then raise exception 'invalid image'; end if;
 end if;
 return new;
end $$;

create function public.admin_media_mutate(p_action text,p_id uuid,p_title text default '',p_body text default '',p_location text default '') returns uuid
language plpgsql security definer set search_path='' as $$
declare g public.ai_generations; r public.rants; result uuid; caption text:=btrim(coalesce(p_body,''));
begin
 perform public.require_superadmin();
 if p_action is null or p_action not in ('create','update','delete') or p_id is null then raise exception 'invalid action';end if;
 select * into g from public.ai_generations where id=p_id for update;
 if not found then raise exception 'generation not found';end if;
 select * into r from public.rants where generation_id=g.id for update;
 if p_action='delete' then
  if r.id is null then raise exception 'publication not found';end if;
  delete from public.rants where id=r.id;
  return r.id;
 end if;
 if char_length(btrim(coalesce(p_title,''))) not between 1 and 120 or char_length(caption)>1000 or char_length(btrim(coalesce(p_location,'')))>120 then raise exception 'invalid media fields';end if;
 if p_action='create' and r.id is not null then raise exception 'already published';end if;
 if p_action='update' and r.id is null then raise exception 'publication not found';end if;
 if g.purpose='meme_caption' then
  if g.caption_choices is not null then
   if not caption=any(g.caption_choices) then raise exception 'choose an original AI caption';end if;
   update public.ai_generations set body=caption,selected_caption=array_position(caption_choices,caption)-1 where id=g.id;
  elsif caption is distinct from g.body then raise exception 'original AI caption required';end if;
 elsif g.media_type<>'image' then
  if caption='' then raise exception 'caption required';end if;
 end if;
 if p_action='create' then
  insert into public.rants(user_id,generation_id,title,body,location)
  values(g.user_id,g.id,btrim(p_title),caption,btrim(coalesce(p_location,''))) returning id into result;
 else
  update public.rants set title=btrim(p_title),body=caption,location=btrim(coalesce(p_location,'')) where id=r.id returning id into result;
 end if;
 return result;
end $$;

revoke all on function public.admin_overview(),public.admin_profiles(text,integer),public.admin_media(text,integer),public.admin_votes(integer),public.admin_media_mutate(text,uuid,text,text,text) from public,anon;
grant execute on function public.admin_overview(),public.admin_profiles(text,integer),public.admin_media(text,integer),public.admin_votes(integer),public.admin_media_mutate(text,uuid,text,text,text) to authenticated;
create policy "Superadmin media preview" on storage.objects for select to authenticated
using(bucket_id in ('ai-cat-images','caption-photos') and public.is_superadmin());
-- No new table privileges; admin reads and writes go through guarded RPCs.
commit;

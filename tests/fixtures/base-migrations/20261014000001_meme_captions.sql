begin;
create function public.valid_meme_template(t jsonb) returns boolean language sql immutable set search_path='' as $$
 select coalesce(jsonb_typeof(t)='object' and jsonb_typeof(t->'name')='string' and char_length(t->>'name') between 1 and 120
 and jsonb_typeof(t->'description')='string' and char_length(t->>'description') between 1 and 1000
 and jsonb_typeof(t->'width')='number' and jsonb_typeof(t->'height')='number'
 and (t->>'width')::numeric between 1 and 10000 and (t->>'height')::numeric between 1 and 10000
 and ((t->>'id'='188390779' and t->>'imageUrl'='https://i.imgflip.com/345v97.jpg' and t->>'sourceUrl'='https://imgflip.com/memetemplate/188390779/Woman-Yelling-At-Cat')
 or (t->>'id'='405658' and t->>'imageUrl'='https://imgflip.com/s/meme/Grumpy-Cat.jpg' and t->>'sourceUrl'='https://imgflip.com/memetemplate/Grumpy-Cat')),false);
$$;
alter table public.ai_generations add column purpose text check(purpose='meme_caption'),add column meme_template jsonb,
 add constraint generation_meme_metadata check((purpose is null and meme_template is null) or
 (purpose='meme_caption' and user_id is not null and media_type='text' and image_path is null and provider='gemini' and model='gemini-3.1-flash-lite'
 and char_length(btrim(prompt)) between 1 and 1000 and char_length(btrim(body)) between 1 and 300 and public.valid_meme_template(meme_template)));
alter table public.rants add column meme_template jsonb,add column meme_scene text,
 add constraint rant_meme_metadata check((meme_template is null and meme_scene is null) or
 (meme_template is not null and meme_scene is not null and generation_id is not null and ai_image_path is null and image_path is null and char_length(btrim(meme_scene)) between 1 and 1000 and char_length(btrim(body)) between 1 and 300 and public.valid_meme_template(meme_template)));
grant select(meme_template,meme_scene) on public.rants to anon,authenticated;
create table public.meme_provider_usage(singleton boolean primary key default true check(singleton),usage_date date not null,attempts integer not null default 0 check(attempts>=0),recent_attempts timestamptz[] not null default '{}');
alter table public.meme_provider_usage enable row level security;
revoke all on public.meme_provider_usage from public,anon,authenticated;
grant all on public.meme_provider_usage to service_role;
create function public.reserve_meme_attempt() returns void language plpgsql security definer set search_path='' as $$
declare u public.meme_provider_usage; stamp timestamptz:=clock_timestamp(); day date:=(stamp at time zone 'America/Los_Angeles')::date; recent timestamptz[];
begin
 insert into public.meme_provider_usage(singleton,usage_date) values(true,day) on conflict do nothing;
 select * into u from public.meme_provider_usage where singleton for update;
 select coalesce(array_agg(a),'{}') into recent from unnest(u.recent_attempts) a where a>stamp-interval '1 minute';
 if cardinality(recent)>=10 or (u.usage_date=day and u.attempts>=400) then raise exception 'quotaExceeded'; end if;
 update public.meme_provider_usage set usage_date=day,attempts=case when u.usage_date=day then u.attempts+1 else 1 end,recent_attempts=array_append(recent,stamp) where singleton;
end $$;
revoke all on function public.reserve_meme_attempt() from public,anon,authenticated;
grant execute on function public.reserve_meme_attempt() to service_role;
create function public.finish_meme_caption(p_user_id uuid,p_token uuid,p_prompt text,p_system_prompt text,p_language text,p_model text,p_caption text,p_template jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare g uuid;
begin
 if char_length(btrim(p_prompt)) not between 1 and 1000 or char_length(btrim(p_caption)) not between 1 and 300 or p_model is distinct from 'gemini-3.1-flash-lite' or p_language not in ('en','zh-CN') or not public.valid_meme_template(p_template) then raise exception 'invalidText'; end if;
 update public.ai_generation_usage set succeeded=succeeded+1,active_token=null,active_until=null where user_id=p_user_id and active_token=p_token and active_until>now() and succeeded<10;
 if not found then raise exception 'generationBusy'; end if;
 insert into public.ai_generations(user_id,prompt,system_prompt,title,body,language,provider,model,media_type,purpose,meme_template)
 values(p_user_id,btrim(p_prompt),p_system_prompt,left(btrim(p_caption),120),btrim(p_caption),p_language,'gemini',p_model,'text','meme_caption',p_template) returning id into g;
 return g;
end $$;
revoke all on function public.finish_meme_caption(uuid,uuid,text,text,text,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.finish_meme_caption(uuid,uuid,text,text,text,text,text,jsonb) to service_role;
create or replace function public.validate_rant_references() returns trigger language plpgsql security definer set search_path='' as $$
declare g public.ai_generations;
begin
 if auth.role() in ('anon','authenticated') then
  if new.user_id is distinct from auth.uid() or new.is_example then raise exception 'invalid owner'; end if;
  if new.generation_id is not null then
   select * into g from public.ai_generations where id=new.generation_id and user_id=auth.uid();
   if not found then raise exception 'invalid generation'; end if;
   if g.purpose='meme_caption' then
    if new.body is distinct from g.body or new.image_path is not null then raise exception 'invalid caption'; end if;
    new.meme_template:=g.meme_template; new.meme_scene:=g.prompt; new.ai_image_path:=null;
   else
    if new.meme_template is not null or new.meme_scene is not null then raise exception 'invalid meme'; end if;
    if g.media_type='image' then
     if not exists(select 1 from storage.objects o where o.bucket_id='ai-cat-images' and o.name=g.image_path and (storage.foldername(o.name))[1]=auth.uid()::text) then raise exception 'invalid generated image'; end if;
     new.ai_image_path:=g.image_path;
    else new.ai_image_path:=null; end if;
   end if;
  else
   if new.meme_template is not null or new.meme_scene is not null then raise exception 'invalid meme'; end if;
   new.ai_image_path:=null;
  end if;
  if new.image_path is not null and not exists(select 1 from storage.objects o where o.bucket_id='rant-photos' and o.name=new.image_path and (storage.foldername(o.name))[1]=auth.uid()::text) then raise exception 'invalid image'; end if;
 end if;
 return new;
end $$;
create function public.publish_meme_caption(p_generation_id uuid,p_title text default '',p_location text default '') returns uuid language plpgsql security invoker set search_path='' as $$
declare g public.ai_generations; result uuid;
begin
 if auth.uid() is null then raise exception 'signInRequired'; end if;
 select * into g from public.ai_generations where id=p_generation_id and user_id=auth.uid() and purpose='meme_caption';
 if not found then raise exception 'invalidText'; end if;
 if char_length(btrim(coalesce(p_title,'')))>120 or char_length(btrim(coalesce(p_location,'')))>120 then raise exception 'invalidText'; end if;
 insert into public.rants(user_id,title,location,body,generation_id) values(auth.uid(),coalesce(nullif(btrim(p_title),''),left(g.body,120)),btrim(coalesce(p_location,'')),g.body,g.id) returning id into result;
 return result;
end $$;
revoke all on function public.publish_meme_caption(uuid,text,text) from public,anon;
grant execute on function public.publish_meme_caption(uuid,text,text) to authenticated;
create function public.meme_feed_page(p_sort text default 'latest',p_window text default 'all',p_offset integer default 0,p_mine boolean default false)
returns table(id uuid,title text,body text,location text,created_at timestamptz,scene text,template jsonb,totals jsonb,"myVote" smallint,"canReuse" boolean)
language plpgsql stable security definer set search_path='' as $$
declare boundary timestamptz;
begin
 if p_sort is null or p_sort not in ('latest','popular') or p_window is null or p_window not in ('week','month','year','all') or p_offset is null or p_offset<0 or p_offset>799992 or p_mine is null then raise exception 'invalidText'; end if;
 if p_window<>'all' then boundary:=date_trunc(p_window,now() at time zone 'America/New_York') at time zone 'America/New_York'; end if;
 return query select r.id,r.title,r.body,r.location,r.created_at,r.meme_scene,r.meme_template,
 jsonb_build_object('upvotes',count(v.id) filter(where v.value=1),'downvotes',count(v.id) filter(where v.value=-1),'score',coalesce(sum(v.value),0)),
 max(v.value) filter(where v.user_id=auth.uid()),coalesce(r.user_id=auth.uid(),false)
 from public.rants r join public.ai_generations g on g.id=r.generation_id and g.purpose='meme_caption' and g.user_id=r.user_id and g.body=r.body and g.meme_template=r.meme_template and g.prompt=r.meme_scene
 left join public.rant_votes v on v.rant_id=r.id
 where r.created_at<=now() and (boundary is null or r.created_at>=boundary) and (not p_mine or r.user_id=auth.uid())
 group by r.id order by case when p_sort='popular' then coalesce(sum(v.value),0) else 0 end desc,r.created_at desc,r.id limit 9 offset p_offset;
end $$;
revoke all on function public.meme_feed_page(text,text,integer,boolean) from public;
grant execute on function public.meme_feed_page(text,text,integer,boolean) to anon,authenticated;
commit;

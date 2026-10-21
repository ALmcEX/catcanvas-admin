begin;
create table public.ai_generations (
 id uuid primary key default gen_random_uuid(), user_id uuid references auth.users(id) on delete cascade,
 prompt text not null check (char_length(prompt) between 1 and 4000), system_prompt text not null,
 title text not null check (char_length(btrim(title)) between 1 and 120),
 body text not null check (char_length(btrim(body)) between 1 and 3000),
 language text not null check (language in ('en','zh-CN')), provider text not null,
 model text, created_at timestamptz not null default now()
);
create table public.rants (
 id uuid primary key default gen_random_uuid(), user_id uuid references auth.users(id) on delete cascade,
 title text not null check (char_length(btrim(title)) between 1 and 120),
 location text not null check (char_length(btrim(location)) between 1 and 120),
 body text not null check (char_length(btrim(body)) between 1 and 3000),
 image_path text, generation_id uuid unique references public.ai_generations(id),
 is_example boolean not null default false, created_at timestamptz not null default now(),
 check ((is_example and user_id is null) or (not is_example and user_id is not null))
);
create table public.rant_votes (
 id uuid primary key default gen_random_uuid(), rant_id uuid not null references public.rants(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade, value smallint not null check (value in (1,-1)),
 created_at timestamptz not null default now(), unique(rant_id,user_id)
);
create table public.rant_comments (
 id uuid primary key default gen_random_uuid(), rant_id uuid not null references public.rants(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 body text not null check (char_length(btrim(body)) between 1 and 1000), created_at timestamptz not null default now()
);
create table public.ai_generation_usage (
 user_id uuid not null references auth.users(id) on delete cascade, usage_date date not null,
 succeeded int not null default 0 check (succeeded between 0 and 10), active_token uuid, active_until timestamptz,
 primary key(user_id,usage_date)
);
create index rants_created_idx on public.rants(created_at desc);
create index rant_comments_rant_idx on public.rant_comments(rant_id,created_at);
create index rant_votes_rant_idx on public.rant_votes(rant_id);
alter table public.ai_generations enable row level security;
alter table public.rants enable row level security;
alter table public.rant_votes enable row level security;
alter table public.rant_comments enable row level security;
alter table public.ai_generation_usage enable row level security;
revoke all on public.ai_generations, public.rants, public.rant_votes, public.rant_comments, public.ai_generation_usage from anon,authenticated;
grant all on public.ai_generations, public.rants, public.rant_votes, public.rant_comments, public.ai_generation_usage to service_role;
grant select on public.ai_generations to authenticated;
grant select(id,title,location,body,image_path,generation_id,is_example,created_at) on public.rants to anon,authenticated;
grant insert(user_id,title,location,body,image_path,generation_id) on public.rants to authenticated;
grant update(title,location,body),delete on public.rants to authenticated;
grant select,insert,update(value),delete on public.rant_votes to authenticated;
grant select(id,rant_id,body,created_at) on public.rant_comments to anon,authenticated;
grant insert(rant_id,user_id,body),update(body),delete on public.rant_comments to authenticated;
create policy rants_read on public.rants for select to anon,authenticated using (true);
create policy rants_create on public.rants for insert to authenticated with check (user_id=(select auth.uid()) and not is_example);
create policy rants_update on public.rants for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()) and not is_example);
create policy rants_delete on public.rants for delete to authenticated using(user_id=(select auth.uid()));
create policy generations_own_read on public.ai_generations for select to authenticated using(user_id=(select auth.uid()));
create policy votes_own on public.rant_votes for all to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy comments_read on public.rant_comments for select to anon,authenticated using(true);
create policy comments_create on public.rant_comments for insert to authenticated with check(user_id=(select auth.uid()));
create policy comments_update on public.rant_comments for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy comments_delete on public.rant_comments for delete to authenticated using(user_id=(select auth.uid()));
create function public.validate_rant_references() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if auth.role() in ('anon','authenticated') then
  if new.user_id is distinct from auth.uid() or new.is_example then raise exception 'invalid owner'; end if;
  if new.generation_id is not null and not exists (select 1 from public.ai_generations g where g.id=new.generation_id and g.user_id=auth.uid()) then raise exception 'invalid generation'; end if;
  if new.image_path is not null and not exists (select 1 from storage.objects o where o.bucket_id='rant-photos' and o.name=new.image_path and (storage.foldername(o.name))[1]=auth.uid()::text) then raise exception 'invalid image'; end if;
 end if;
 return new;
end $$;
create trigger rant_references before insert or update on public.rants for each row execute function public.validate_rant_references();
revoke all on function public.validate_rant_references() from public;
create function public.rant_vote_totals(p_rant_id uuid default null)
returns table(rant_id uuid,upvotes bigint,downvotes bigint,score bigint) language sql stable security definer set search_path='' as $$
 select r.id,count(v.id) filter(where v.value=1),count(v.id) filter(where v.value=-1),coalesce(sum(v.value),0)::bigint
 from public.rants r left join public.rant_votes v on v.rant_id=r.id
 where p_rant_id is null or r.id=p_rant_id group by r.id;
$$;
revoke all on function public.rant_vote_totals(uuid) from public;
grant execute on function public.rant_vote_totals(uuid) to anon,authenticated;
create function public.toggle_rant_vote(p_rant_id uuid,p_value smallint) returns void language plpgsql security invoker set search_path='' as $$
declare old_value smallint;
begin
 if auth.uid() is null then raise exception 'sign in required'; end if;
 if p_value not in (1,-1) or p_value is null then raise exception 'invalid vote'; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text || p_rant_id::text,0));
 select value into old_value from public.rant_votes where rant_id=p_rant_id and user_id=auth.uid();
 if old_value=p_value then delete from public.rant_votes where rant_id=p_rant_id and user_id=auth.uid();
 else insert into public.rant_votes(rant_id,user_id,value) values(p_rant_id,auth.uid(),p_value)
 on conflict(rant_id,user_id) do update set value=excluded.value; end if;
end $$;
revoke all on function public.toggle_rant_vote(uuid,smallint) from public;
grant execute on function public.toggle_rant_vote(uuid,smallint) to authenticated;
create function public.reserve_ai_generation(p_user_id uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare d date := (now() at time zone 'America/New_York')::date; u public.ai_generation_usage; token uuid:=gen_random_uuid();
begin
 insert into public.ai_generation_usage(user_id,usage_date) values(p_user_id,d) on conflict do nothing;
 select * into u from public.ai_generation_usage where user_id=p_user_id and usage_date=d for update;
 if u.succeeded>=10 then raise exception 'quotaExceeded'; end if;
 if u.active_until>now() then raise exception 'generationBusy'; end if;
 update public.ai_generation_usage set active_token=token,active_until=now()+interval '2 minutes' where user_id=p_user_id and usage_date=d;
 return token;
end $$;
create function public.release_ai_generation(p_user_id uuid,p_token uuid) returns void language sql security definer set search_path='' as $$
 update public.ai_generation_usage set active_token=null,active_until=null where user_id=p_user_id and active_token=p_token;
$$;
create function public.finish_ai_generation(p_user_id uuid,p_token uuid,p_prompt text,p_system_prompt text,p_title text,p_body text,p_language text,p_model text)
returns uuid language plpgsql security definer set search_path='' as $$
declare g uuid;
begin
 update public.ai_generation_usage set succeeded=succeeded+1,active_token=null,active_until=null
 where user_id=p_user_id and active_token=p_token and active_until>now() and succeeded<10;
 if not found then raise exception 'generationBusy'; end if;
 insert into public.ai_generations(user_id,prompt,system_prompt,title,body,language,provider,model)
 values(p_user_id,p_prompt,p_system_prompt,p_title,p_body,p_language,'gemini',p_model) returning id into g;
 return g;
end $$;
revoke all on function public.reserve_ai_generation(uuid),public.release_ai_generation(uuid,uuid),public.finish_ai_generation(uuid,uuid,text,text,text,text,text,text) from public,anon,authenticated;
grant execute on function public.reserve_ai_generation(uuid),public.release_ai_generation(uuid,uuid),public.finish_ai_generation(uuid,uuid,text,text,text,text,text,text) to service_role;
update storage.buckets set public=false where id='avatars';
drop policy if exists "Avatar images are publicly accessible" on storage.objects;
create policy "Users can read their own avatars" on storage.objects for select to authenticated using(bucket_id='avatars' and (storage.foldername(name))[1]=(select auth.uid()::text));
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('rant-photos','rant-photos',true,5242880,array['image/jpeg','image/png','image/webp']);
create policy "Rant photos readable" on storage.objects for select to anon,authenticated using(bucket_id='rant-photos');
create policy "Rant photos own insert" on storage.objects for insert to authenticated with check(bucket_id='rant-photos' and (storage.foldername(name))[1]=(select auth.uid()::text));
create policy "Rant photos own delete" on storage.objects for delete to authenticated using(bucket_id='rant-photos' and (storage.foldername(name))[1]=(select auth.uid()::text));
-- Retain existing table policies while ensuring all application tables have RLS.
do $$ declare t record; begin
 for t in select tablename from pg_tables where schemaname='public' loop
  execute format('alter table public.%I enable row level security',t.tablename);
 end loop;
end $$;
create function public.rant_feed(p_sort text default 'latest') returns table(id uuid,title text,location text)
language sql stable security definer set search_path='' as $$
 select r.id,r.title,r.location from public.rants r left join public.rant_votes v on v.rant_id=r.id
 group by r.id order by case when p_sort='popular' then coalesce(sum(v.value),0) else 0 end desc,r.created_at desc,r.id limit 100;
$$;
revoke all on function public.rant_feed(text) from public;
grant execute on function public.rant_feed(text) to anon,authenticated;
commit;

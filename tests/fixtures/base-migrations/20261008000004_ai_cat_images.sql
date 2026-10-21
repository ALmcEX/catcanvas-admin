begin;
alter table public.ai_generations
 add column media_type text not null default 'text' check (media_type in ('text','image')),
 add column image_path text,
 add column mime_type text check (mime_type in ('image/png','image/jpeg','image/webp')),
 add column cat_breed text check (cat_breed in ('orange','tabby','ragdoll','british','tuxedo','calico')),
 add column art_style text check (art_style in ('photo','illustration','clay')),
 add constraint generation_image_metadata check ((media_type='text' and image_path is null) or (media_type='image' and user_id is not null and image_path is not null and mime_type is not null and cat_breed is not null and art_style is not null));
alter table public.rants add column ai_image_path text;
grant select(ai_image_path) on public.rants to anon,authenticated;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('ai-cat-images','ai-cat-images',false,5242880,array['image/jpeg','image/png','image/webp']);
-- Draft images are visible to their author; only published images are readable by guests.
create policy "AI cat images own or published read" on storage.objects for select to anon,authenticated
using(bucket_id='ai-cat-images' and (
 (storage.foldername(name))[1]=(select auth.uid()::text)
 or exists(select 1 from public.rants r where r.ai_image_path=storage.objects.name)
));
-- No browser INSERT/UPDATE/DELETE policy: the server stores immutable outputs.
create or replace function public.validate_rant_references() returns trigger language plpgsql security definer set search_path='' as $$
declare g public.ai_generations;
begin
 if auth.role() in ('anon','authenticated') then
  if new.user_id is distinct from auth.uid() or new.is_example then raise exception 'invalid owner'; end if;
  if new.generation_id is not null then
   select * into g from public.ai_generations where id=new.generation_id and user_id=auth.uid();
   if not found then raise exception 'invalid generation'; end if;
   if g.media_type='image' then
    if not exists(select 1 from storage.objects o where o.bucket_id='ai-cat-images' and o.name=g.image_path and (storage.foldername(o.name))[1]=auth.uid()::text) then raise exception 'invalid generated image'; end if;
    new.ai_image_path := g.image_path;
   else new.ai_image_path := null; end if;
  else new.ai_image_path := null; end if;
  if new.image_path is not null and not exists(select 1 from storage.objects o where o.bucket_id='rant-photos' and o.name=new.image_path and (storage.foldername(o.name))[1]=auth.uid()::text) then raise exception 'invalid image'; end if;
 end if;
 return new;
end $$;
create function public.finish_ai_cat_image(p_user_id uuid,p_token uuid,p_prompt text,p_system_prompt text,p_language text,p_model text,p_image_path text,p_mime_type text,p_breed text,p_style text)
returns uuid language plpgsql security definer set search_path='' as $$
declare g uuid;
begin
 if not exists(select 1 from storage.objects o where o.bucket_id='ai-cat-images' and o.name=p_image_path and (storage.foldername(o.name))[1]=p_user_id::text) then raise exception 'invalid generated image'; end if;
 update public.ai_generation_usage set succeeded=succeeded+1,active_token=null,active_until=null
 where user_id=p_user_id and active_token=p_token and active_until>now() and succeeded<10;
 if not found then raise exception 'generationBusy'; end if;
 insert into public.ai_generations(user_id,prompt,system_prompt,title,body,language,provider,model,media_type,image_path,mime_type,cat_breed,art_style)
 values(p_user_id,p_prompt,p_system_prompt,'AI cat image',p_prompt,p_language,'gemini',p_model,'image',p_image_path,p_mime_type,p_breed,p_style) returning id into g;
 return g;
end $$;
revoke all on function public.finish_ai_cat_image(uuid,uuid,text,text,text,text,text,text,text,text) from public,anon,authenticated;
grant execute on function public.finish_ai_cat_image(uuid,uuid,text,text,text,text,text,text,text,text) to service_role;
commit;

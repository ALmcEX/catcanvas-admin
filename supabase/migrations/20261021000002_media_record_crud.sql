begin;
alter table public.ai_generations add column admin_version integer not null default 0,
 add column admin_caption text check(char_length(admin_caption)<=1000);
alter table public.ai_generations drop constraint generation_meme_metadata;
alter table public.ai_generations add constraint generation_meme_metadata check((purpose is null and meme_template is null) or
 (purpose='meme_caption' and user_id is not null and media_type='text' and image_path is null
 and ((provider='gemini' and model='gemini-3.1-flash-lite') or (provider='admin_import' and char_length(btrim(model)) between 1 and 120))
 and char_length(btrim(prompt)) between 1 and 1000 and char_length(btrim(body)) between 1 and 300 and public.valid_meme_template(meme_template)));
create table public.admin_media_audit(
 id uuid primary key default gen_random_uuid(),media_id uuid not null,
 actor_id uuid references auth.users(id) on delete set null,
 action text not null check(action in ('create','update','delete','upload_cleanup')),
 before_record jsonb,before_post jsonb,created_at timestamptz not null default now(),
 assets jsonb not null default '[]',cleanup_complete boolean not null default true
);
alter table public.admin_media_audit enable row level security;
revoke all on public.admin_media_audit from public,anon,authenticated;
grant all on public.admin_media_audit to service_role;

create function public.admin_asset_unused(p_bucket text,p_path text) returns boolean
language sql stable security definer set search_path='' as $$
 select public.is_superadmin() and case
 when p_bucket='ai-cat-images' then not exists(select 1 from public.ai_generations where image_path=p_path) and not exists(select 1 from public.rants where ai_image_path=p_path)
 when p_bucket='caption-photos' then not exists(select 1 from public.ai_generations where meme_template->>'storagePath'=p_path) and not exists(select 1 from public.rants where meme_template->>'storagePath'=p_path)
 when p_bucket='rant-photos' then not exists(select 1 from public.rants where image_path=p_path)
 else false end
$$;
revoke all on function public.admin_asset_unused(text,text) from public,anon;
grant execute on function public.admin_asset_unused(text,text) to authenticated;
create policy "Superadmin image imports" on storage.objects for insert to authenticated
with check(bucket_id in ('ai-cat-images','caption-photos') and public.is_superadmin()
 and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}[.](png|jpg|webp)$');
create policy "Superadmin unused asset cleanup" on storage.objects for delete to authenticated
using(public.admin_asset_unused(bucket_id,name));

-- Invalidate admin forms when the original app or legacy RPC changes a publication.
create function public.admin_publication_revision() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if TG_OP='DELETE' then
  update public.ai_generations set admin_version=admin_version+1 where id=old.generation_id;
  return old;
 end if;
 if TG_OP='UPDATE' and old.generation_id is distinct from new.generation_id then
  update public.ai_generations set admin_version=admin_version+1 where id=old.generation_id;
 end if;
 update public.ai_generations set admin_version=admin_version+1 where id=new.generation_id;
 return new;
end $$;
revoke all on function public.admin_publication_revision() from public,anon,authenticated;
create trigger admin_publication_revision after insert or update or delete on public.rants
for each row execute function public.admin_publication_revision();

-- Persist failed-upload compensation before attempting Storage removal.
create function public.admin_media_queue_upload_cleanup(p_bucket text,p_path text) returns uuid
language plpgsql security definer set search_path='' as $$
declare receipt uuid;
begin
 perform public.require_superadmin();
 if p_bucket not in ('ai-cat-images','caption-photos') or p_path is null
  or p_path !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}[.](png|jpg|webp)$' then raise exception 'invalid cleanup asset';end if;
 if not public.admin_asset_unused(p_bucket,p_path) then return null;end if;
 insert into public.admin_media_audit(media_id,actor_id,action,assets,cleanup_complete)
 values(gen_random_uuid(),auth.uid(),'upload_cleanup',jsonb_build_array(jsonb_build_object('bucket',p_bucket,'path',p_path)),false)
 returning id into receipt;
 return receipt;
end $$;
revoke all on function public.admin_media_queue_upload_cleanup(text,text) from public,anon;
grant execute on function public.admin_media_queue_upload_cleanup(text,text) to authenticated;

create function public.admin_media_record(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 perform public.require_superadmin();
 select to_jsonb(g)||jsonb_build_object('version',g.admin_version,'generated_body',g.body,'post_id',r.id,
 'title',coalesce(r.title,g.title),'body',coalesce(r.body,g.admin_caption,case when g.media_type='image' then '' else g.body end),
 'location',coalesce(r.location,''),'votes',(select count(*) from public.rant_votes v where v.rant_id=r.id),
 'comments',(select count(*) from public.rant_comments c where c.rant_id=r.id))
 into result from public.ai_generations g left join public.rants r on r.generation_id=g.id
 where g.id=p_id and g.user_id is not null;
 return result;
end $$;
create or replace function public.admin_media(p_query text default '',p_page integer default 0) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb; q text:=left(coalesce(p_query,''),120);
begin
 perform public.require_superadmin();
 if p_page is null or p_page<0 or p_page>10000 then raise exception 'invalid page';end if;
 select jsonb_build_object('rows',(select coalesce(jsonb_agg(public.admin_media_record(x.id)),'[]') from (
 select g.id from public.ai_generations g left join public.rants r on r.generation_id=g.id
 where g.user_id is not null and concat_ws(' ',g.title,g.prompt,g.id::text,r.title) ilike '%'||q||'%'
 order by g.created_at desc,g.id limit 20 offset p_page*20) x),
 'total',(select count(*) from public.ai_generations g left join public.rants r on r.generation_id=g.id where g.user_id is not null and concat_ws(' ',g.title,g.prompt,g.id::text,r.title) ilike '%'||q||'%')) into result;
 return result;
end $$;

create function public.admin_media_save(p_record jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
#variable_conflict use_variable
declare g public.ai_generations;r public.rants; gid uuid; owner_id uuid; kind text:=p_record->>'kind';
 title text:=btrim(p_record->>'title'); prompt text:=btrim(p_record->>'prompt'); caption text:=btrim(coalesce(p_record->>'body',''));
 model text:=btrim(p_record->>'model'); location text:=btrim(coalesce(p_record->>'location',''));
 file jsonb:=p_record->'file'; template jsonb; media_path text; mime text; old_path text;old_bucket text;
 publish boolean:=coalesce((p_record->>'publish')::boolean,false);audit_id uuid;new_version integer:=0;
 assets jsonb:='[]';
begin
 perform public.require_superadmin();
 if kind is null or kind not in ('image','caption','text') or title is null or char_length(title) not between 1 and 120
 or prompt is null or char_length(prompt) not between 1 and 1000 or model is null or char_length(model) not between 1 and 120
 or char_length(location)>120 or (kind='caption' and char_length(caption) not between 1 and 300)
 or (kind='image' and char_length(caption)>1000) or (kind='text' and char_length(caption) not between 1 and 3000) then raise exception 'invalid media fields';end if;
 if nullif(p_record->>'id','') is not null then
  select * into g from public.ai_generations where id=(p_record->>'id')::uuid and user_id is not null for update;
  if not found then raise exception 'media not found';end if;
  if p_record ? 'version' and (p_record->>'version')::integer is distinct from g.admin_version then raise exception 'media changed; refresh before saving';end if;
  if kind is distinct from (case when g.media_type='image' then 'image' when g.purpose='meme_caption' then 'caption' else 'text' end) then raise exception 'media type cannot change';end if;
  select * into r from public.rants where generation_id=g.id for update;
  owner_id:=g.user_id;gid:=g.id;template:=g.meme_template;new_version:=g.admin_version+1;
  if g.provider<>'admin_import' and (file is null or file='null'::jsonb) then model:=g.model;end if;
  old_path:=case when kind='image' then g.image_path else g.meme_template->>'storagePath' end;
  old_bucket:=case when kind='image' then 'ai-cat-images' else 'caption-photos' end;
 else
  if (p_record->>'attestation')::boolean is distinct from true then raise exception 'AI source attestation required';end if;
  if kind='text' then raise exception 'new imports must be images or captions';end if;
  owner_id:=auth.uid();gid:=gen_random_uuid();
  template:='{"id":"405658","name":"Grumpy Cat","description":"Grumpy Cat template","width":600,"height":600,"imageUrl":"https://imgflip.com/s/meme/Grumpy-Cat.jpg","sourceUrl":"https://imgflip.com/memetemplate/Grumpy-Cat"}';
 end if;
 if file is not null and file<>'null'::jsonb then
  media_path:=file->>'path';mime:=file->>'mime';
  if file->>'bucket' is distinct from (case when kind='image' then 'ai-cat-images' else 'caption-photos' end)
   or kind='text' or mime is null or mime not in ('image/png','image/jpeg','image/webp')
   or coalesce((file->>'width')::integer,0) not between 1 and 10000 or coalesce((file->>'height')::integer,0) not between 1 and 10000
   or (storage.foldername(media_path))[1] is distinct from owner_id::text
   or not exists(select 1 from storage.objects where bucket_id=file->>'bucket' and name=media_path)
   then raise exception 'invalid imported asset';end if;
  if kind='caption' then
   template:=jsonb_build_object('id','uploaded','name','Imported AI caption photo','description','Admin-imported photo','width',(file->>'width')::integer,'height',(file->>'height')::integer,'imageUrl','','sourceUrl','','storagePath',media_path);
  end if;
 elsif kind='image' then media_path:=g.image_path;mime:=g.mime_type;
 end if;
 if kind='image' and media_path is null then raise exception 'an image file is required';end if;
 if g.id is null then
  insert into public.ai_generations(id,user_id,title,prompt,system_prompt,body,language,provider,model,media_type,purpose,image_path,mime_type,cat_breed,art_style,meme_template,admin_caption)
  values(gid,owner_id,title,prompt,'Imported by an administrator; source metadata supplied by the administrator. No provider call was made.',case when kind='image' then prompt else caption end,'en','admin_import',model,case when kind='image' then 'image' else 'text' end,case when kind='caption' then 'meme_caption' end,case when kind='image' then media_path end,case when kind='image' then mime end,case when kind='image' then coalesce(p_record->>'breed','orange') end,case when kind='image' then coalesce(p_record->>'style','photo') end,case when kind='caption' then template end,case when kind='image' then caption end);
 else
  update public.ai_generations set title=title,prompt=prompt,model=model,
   provider=case when file is not null and file<>'null'::jsonb then 'admin_import' else g.provider end,
   body=case when kind='image' then g.body else caption end,
   selected_caption=case when kind='caption' and g.caption_choices is not null then array_position(g.caption_choices,caption)-1 else g.selected_caption end,
   meme_template=case when kind='caption' then template else g.meme_template end,
   image_path=case when kind='image' then media_path else g.image_path end,
   mime_type=case when kind='image' then mime else g.mime_type end,
   admin_caption=case when kind='image' then caption else g.admin_caption end,admin_version=new_version
  where id=gid;
 end if;
 if publish or r.id is not null then
  if r.id is null then insert into public.rants(user_id,generation_id,title,body,location) values(owner_id,gid,title,caption,location);
  else update public.rants set title=title,body=caption,location=location where id=r.id;end if;
 end if;
 if old_path is not null and file is not null and file<>'null'::jsonb and old_path is distinct from media_path and public.admin_asset_unused(old_bucket,old_path) then
  assets:=jsonb_build_array(jsonb_build_object('bucket',old_bucket,'path',old_path));
 end if;
 insert into public.admin_media_audit(media_id,actor_id,action,before_record,before_post,assets,cleanup_complete)
 values(gid,auth.uid(),case when g.id is null then 'create' else 'update' end,case when g.id is null then null else to_jsonb(g) end,case when r.id is null then null else to_jsonb(r) end,assets,jsonb_array_length(assets)=0);
 return gid;
end $$;

create function public.admin_media_delete(p_id uuid,p_version integer default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare g public.ai_generations;r public.rants;assets jsonb:='[]';receipt uuid;candidate jsonb;
begin
 perform public.require_superadmin();
 select * into g from public.ai_generations where id=p_id and user_id is not null for update;
 if not found then raise exception 'media not found';end if;
 if p_version is not null and p_version<>g.admin_version then raise exception 'media changed; refresh before deleting';end if;
 select * into r from public.rants where generation_id=g.id for update;
 delete from public.rants where generation_id=g.id;
 delete from public.ai_generations where id=g.id;
 for candidate in select x from jsonb_array_elements(jsonb_build_array(
  jsonb_build_object('bucket','ai-cat-images','path',g.image_path),
  jsonb_build_object('bucket','caption-photos','path',g.meme_template->>'storagePath'),
  jsonb_build_object('bucket','rant-photos','path',r.image_path))) x loop
  if candidate->>'path' is not null and public.admin_asset_unused(candidate->>'bucket',candidate->>'path') then assets:=assets||jsonb_build_array(candidate);end if;
 end loop;
 insert into public.admin_media_audit(media_id,actor_id,action,before_record,before_post,assets,cleanup_complete)
 values(g.id,auth.uid(),'delete',to_jsonb(g),case when r.id is null then null else to_jsonb(r) end,assets,jsonb_array_length(assets)=0) returning id into receipt;
 return jsonb_build_object('receipt',receipt,'assets',assets);
end $$;
create function public.admin_media_pending_cleanup() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 perform public.require_superadmin();
 select coalesce(jsonb_agg(x),'[]') into result from (
 select id,media_id,assets from public.admin_media_audit where not cleanup_complete order by created_at limit 50) x;
 return result;
end $$;
create function public.admin_media_mark_clean(p_receipt uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform public.require_superadmin();
 if exists(select 1 from public.admin_media_audit a,jsonb_array_elements(a.assets) f join storage.objects o on o.bucket_id=f->>'bucket' and o.name=f->>'path' where a.id=p_receipt) then raise exception 'asset cleanup is not complete';end if;
 update public.admin_media_audit set cleanup_complete=true where id=p_receipt;
end $$;
revoke all on function public.admin_media_record(uuid),public.admin_media_save(jsonb),public.admin_media_delete(uuid,integer),public.admin_media_pending_cleanup(),public.admin_media_mark_clean(uuid) from public,anon;
grant execute on function public.admin_media_record(uuid),public.admin_media_save(jsonb),public.admin_media_delete(uuid,integer),public.admin_media_pending_cleanup(),public.admin_media_mark_clean(uuid) to authenticated;
commit;

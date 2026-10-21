begin;
create or replace function public.valid_meme_template(t jsonb) returns boolean language sql immutable set search_path='' as $$
 select coalesce(jsonb_typeof(t)='object' and jsonb_typeof(t->'name')='string' and char_length(t->>'name') between 1 and 120
 and jsonb_typeof(t->'description')='string' and char_length(t->>'description') between 1 and 1000
 and jsonb_typeof(t->'width')='number' and jsonb_typeof(t->'height')='number'
 and (t->>'width')::numeric between 1 and 10000 and (t->>'height')::numeric between 1 and 10000
 and ((t->>'id'='188390779' and t->>'imageUrl'='https://i.imgflip.com/345v97.jpg' and t->>'sourceUrl'='https://imgflip.com/memetemplate/188390779/Woman-Yelling-At-Cat')
 or (t->>'id'='405658' and t->>'imageUrl'='https://imgflip.com/s/meme/Grumpy-Cat.jpg' and t->>'sourceUrl'='https://imgflip.com/memetemplate/Grumpy-Cat')
 or (t->>'id'='uploaded' and t->>'imageUrl'='' and t->>'sourceUrl'=''
 and t->>'storagePath' ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}[.](png|jpg|webp)$')),false);
$$;

alter table public.ai_generations add column caption_choices text[],add column selected_caption integer;
create function public.valid_caption_choices(c text[]) returns boolean language sql immutable set search_path='' as $$
 select coalesce(array_ndims(c)=1 and array_lower(c,1)=1 and cardinality(c)=4
 and (select count(distinct lower(btrim(x)))=4 and bool_and(x is not null and char_length(btrim(x)) between 1 and 300) from unnest(c) x),false)
$$;
alter table public.ai_generations add constraint caption_choices_valid check (
 (caption_choices is null and selected_caption is null)
 or (purpose='meme_caption' and public.valid_caption_choices(caption_choices) and (selected_caption is null or selected_caption between 0 and 3))
);
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('caption-photos','caption-photos',false,3145728,array['image/jpeg','image/png','image/webp']);
create policy "Caption photos own or published read" on storage.objects for select to anon,authenticated
using(bucket_id='caption-photos' and (
 (select auth.uid()::text)=(storage.foldername(name))[1]
 or exists(select 1 from public.rants r where r.meme_template->>'id'='uploaded' and r.meme_template->>'storagePath'=name)
));
create function public.finish_caption_choices(p_user_id uuid,p_token uuid,p_prompt text,p_system_prompt text,p_language text,p_model text,p_captions text[],p_template jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare g uuid;
begin
 if not public.valid_caption_choices(p_captions) then raise exception 'invalidText'; end if;
 if p_template->>'id'='uploaded' and not exists (
  select 1 from storage.objects o where o.bucket_id='caption-photos' and o.name=p_template->>'storagePath' and (storage.foldername(o.name))[1]=p_user_id::text
 ) then raise exception 'invalidPhoto'; end if;
 g:=public.finish_meme_caption(p_user_id,p_token,p_prompt,p_system_prompt,p_language,p_model,btrim(p_captions[1]),p_template);
 update public.ai_generations set caption_choices=array(select btrim(c) from unnest(p_captions) c),title='AI caption' where id=g;
 return g;
end $$;
revoke all on function public.finish_caption_choices(uuid,uuid,text,text,text,text,text[],jsonb) from public,anon,authenticated;
grant execute on function public.finish_caption_choices(uuid,uuid,text,text,text,text,text[],jsonb) to service_role;

create function public.publish_caption_choice(p_generation_id uuid,p_choice_index integer,p_location text default '')
returns uuid language plpgsql security definer set search_path='' as $$
declare g public.ai_generations; result uuid; caption text;
begin
 if auth.uid() is null then raise exception 'signInRequired'; end if;
 if p_choice_index is null or p_choice_index not between 0 and 3 or char_length(btrim(coalesce(p_location,'')))>120 then raise exception 'invalidText'; end if;
 select * into g from public.ai_generations where id=p_generation_id and user_id=auth.uid() and purpose='meme_caption' for update;
 if not found or not public.valid_caption_choices(g.caption_choices) then raise exception 'invalidText'; end if;
 if exists(select 1 from public.rants where generation_id=g.id) then raise exception 'invalidText'; end if;
 caption:=g.caption_choices[p_choice_index+1];
 update public.ai_generations set body=caption,title='AI caption',selected_caption=p_choice_index where id=g.id;
 insert into public.rants(user_id,title,location,body,generation_id)
 values(auth.uid(),'AI caption',btrim(coalesce(p_location,'')),caption,g.id) returning id into result;
 return result;
end $$;
revoke all on function public.publish_caption_choice(uuid,integer,text) from public,anon;
grant execute on function public.publish_caption_choice(uuid,integer,text) to authenticated;
commit;

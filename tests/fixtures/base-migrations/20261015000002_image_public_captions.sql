begin;
alter table public.rants drop constraint rants_body_check;
alter table public.rants add constraint rants_body_check check (
 char_length(btrim(body)) between 1 and 3000
 or (ai_image_path is not null and char_length(btrim(body))=0)
);
-- Remove former automatic prompt copies from public image posts only.
update public.rants r set
 body=case when r.body=g.prompt then '' else r.body end,
 title=case when r.title=left(btrim(g.prompt),120) then 'AI cat image' else r.title end
from public.ai_generations g
where r.generation_id=g.id and g.media_type='image' and r.ai_image_path is not null
 and (r.body=g.prompt or r.title=left(btrim(g.prompt),120));

create function public.publish_cat_image_with_caption(p_generation_id uuid,p_title text default '',p_location text default '',p_caption text default '') returns uuid
language plpgsql security invoker set search_path='' as $$
declare g public.ai_generations; new_id uuid;
begin
 if auth.uid() is null then raise exception 'signInRequired'; end if;
 select * into g from public.ai_generations where id=p_generation_id and user_id=auth.uid() and media_type='image';
 if not found then raise exception 'invalidText'; end if;
 if char_length(btrim(coalesce(p_title,'')))>120 or char_length(btrim(coalesce(p_location,'')))>120 or char_length(btrim(coalesce(p_caption,'')))>1000 then raise exception 'invalidText'; end if;
 insert into public.rants(user_id,title,body,location,generation_id)
 values(auth.uid(),coalesce(nullif(btrim(p_title),''),'AI cat image'),btrim(coalesce(p_caption,'')),btrim(coalesce(p_location,'')),g.id)
 returning id into new_id;
 return new_id;
end $$;
revoke all on function public.publish_cat_image_with_caption(uuid,text,text,text) from public,anon;
grant execute on function public.publish_cat_image_with_caption(uuid,text,text,text) to authenticated;

-- Older deployments must also stop publishing prompts.
create or replace function public.publish_cat_image(p_generation_id uuid,p_title text default '',p_location text default '') returns uuid
language sql security invoker set search_path='' as $$
 select public.publish_cat_image_with_caption(p_generation_id,p_title,p_location,'')
$$;
commit;

begin;
create or replace function public.is_superadmin() returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select p.is_superadmin from public.profiles p
 where p.id=auth.uid()
 and auth.jwt()->'app_metadata'->>'provider'='google'
 and exists(select 1 from jsonb_array_elements(coalesce(auth.jwt()->'amr','[]'::jsonb)) a where a->>'method'='oauth')
 and not exists(select 1 from auth.identities i where i.user_id=p.id and i.provider<>'google')
 and exists(select 1 from auth.identities i where i.user_id=p.id and i.provider='google')),false)
$$;
create or replace function public.admin_overview() returns jsonb
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

create or replace function public.admin_media(p_query text default '',p_page integer default 0) returns jsonb
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

commit;

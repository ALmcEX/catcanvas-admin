begin;
alter table public.rants drop constraint rants_location_check;
alter table public.rants add constraint rants_location_check check(char_length(btrim(location)) between 0 and 120);
create function public.cat_feed_page(p_sort text default 'latest',p_window text default 'all',p_offset integer default 0,p_mine boolean default false)
returns table(id uuid,title text,body text,location text,created_at timestamptz,ai_image_path text,breed text,style text,totals jsonb,"myVote" smallint,"canReuse" boolean)
language plpgsql stable security definer set search_path='' as $$
declare boundary timestamptz;
begin
 if p_sort is null or p_sort not in ('latest','popular') or p_window is null or p_window not in ('week','month','year','all') or p_offset is null or p_offset<0 or p_offset>799992 or p_mine is null then raise exception 'invalidText'; end if;
 if p_window<>'all' then boundary:=date_trunc(p_window,now() at time zone 'America/New_York') at time zone 'America/New_York'; end if;
 return query
 select r.id,r.title,r.body,r.location,r.created_at,r.ai_image_path,g.cat_breed,g.art_style,
 jsonb_build_object('upvotes',count(v.id) filter(where v.value=1),'downvotes',count(v.id) filter(where v.value=-1),'score',coalesce(sum(v.value),0)),
 max(v.value) filter(where v.user_id=auth.uid()),coalesce(r.user_id=auth.uid(),false)
 from public.rants r join public.ai_generations g on g.id=r.generation_id and g.media_type='image' and g.image_path=r.ai_image_path
 left join public.rant_votes v on v.rant_id=r.id
 where r.ai_image_path is not null and r.created_at<=now() and (boundary is null or r.created_at>=boundary)
 and (not p_mine or r.user_id=auth.uid())
 group by r.id,g.cat_breed,g.art_style
 order by case when p_sort='popular' then coalesce(sum(v.value),0) else 0 end desc,r.created_at desc,r.id
 limit 9 offset p_offset;
end $$;
revoke all on function public.cat_feed_page(text,text,integer,boolean) from public;
grant execute on function public.cat_feed_page(text,text,integer,boolean) to anon,authenticated;
create function public.publish_cat_image(p_generation_id uuid,p_title text default '',p_location text default '') returns uuid
language plpgsql security invoker set search_path='' as $$
declare g public.ai_generations; new_id uuid;
begin
 if auth.uid() is null then raise exception 'signInRequired'; end if;
 select * into g from public.ai_generations where id=p_generation_id and user_id=auth.uid() and media_type='image';
 if not found then raise exception 'invalidText'; end if;
 if char_length(btrim(coalesce(p_title,'')))>120 or char_length(btrim(coalesce(p_location,'')))>120 or char_length(btrim(g.prompt)) not between 1 and 1000 then raise exception 'invalidText'; end if;
 insert into public.rants(user_id,title,body,location,generation_id)
 values(auth.uid(),coalesce(nullif(btrim(p_title),''),left(btrim(g.prompt),120)),g.prompt,btrim(coalesce(p_location,'')),g.id)
 returning id into new_id;
 return new_id;
end $$;
revoke all on function public.publish_cat_image(uuid,text,text) from public,anon;
grant execute on function public.publish_cat_image(uuid,text,text) to authenticated;
commit;

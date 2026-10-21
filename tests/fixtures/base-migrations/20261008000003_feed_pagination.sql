create function public.rant_feed_page(p_sort text default 'latest',p_offset integer default 0) returns table(id uuid,title text,location text)
language sql stable security definer set search_path='' as $$
 select r.id,r.title,r.location from public.rants r left join public.rant_votes v on v.rant_id=r.id
 group by r.id order by case when p_sort='popular' then coalesce(sum(v.value),0) else 0 end desc,r.created_at desc,r.id
 limit 21 offset greatest(0,p_offset);
$$;
revoke all on function public.rant_feed_page(text,integer) from public;
grant execute on function public.rant_feed_page(text,integer) to anon,authenticated;

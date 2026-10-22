begin;
-- Account email is read from Auth only inside the existing superadmin-guarded RPC.
create or replace function public.admin_profiles(p_query text default '',p_page integer default 0) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb; q text:=left(coalesce(p_query,''),120);
begin
 perform public.require_superadmin();
 if p_page is null or p_page<0 or p_page>10000 then raise exception 'invalid page';end if;
 select jsonb_build_object('rows',(select coalesce(jsonb_agg(x),'[]') from (
 select p.id,p.first_name,p.last_name,p.created_at,p.is_superadmin,u.email,
 (select count(*) from public.ai_generations g where g.user_id=p.id) as generations,
 (select count(*) from public.rant_votes v where v.user_id=p.id) as votes
 from public.profiles p left join auth.users u on u.id=p.id where concat_ws(' ',p.first_name,p.last_name,p.id::text,u.email) ilike '%'||q||'%'
 order by p.created_at desc,p.id limit 20 offset p_page*20) x),
 'total',(select count(*) from public.profiles p left join auth.users u on u.id=p.id where concat_ws(' ',p.first_name,p.last_name,p.id::text,u.email) ilike '%'||q||'%')) into result;
 return result;
end $$;

revoke all on function public.admin_profiles(text,integer) from public,anon;
grant execute on function public.admin_profiles(text,integer) to authenticated;
commit;

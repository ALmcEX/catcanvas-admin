-- Owner approved a $5 test budget on 2026-10-15.
-- Lifetime cap: 10 provider attempts, including failures/timeouts. Never reset daily.
-- Pinned Flash Lite Image, one 1K image, max4096 output tokens, <=1000 prompt
-- characters + <=120 location characters. Reserve a conservative $0.50 per call.
-- This bounds this application's image requests, not unrelated Google project use.
begin;
create table public.image_test_budget (
 singleton boolean primary key default true check(singleton),
 attempts integer not null default 0 check(attempts between 0 and 10)
);
alter table public.image_test_budget enable row level security;
revoke all on public.image_test_budget from public,anon,authenticated,service_role;
grant select on public.image_test_budget to service_role;
insert into public.image_test_budget(singleton) values(true);
create function public.reserve_image_test_attempt() returns void
language plpgsql security definer set search_path='' as $$
begin
 update public.image_test_budget set attempts=attempts+1 where singleton and attempts<10;
 if not found then raise exception 'quotaExceeded'; end if;
end $$;
revoke all on function public.reserve_image_test_attempt() from public,anon,authenticated;
grant execute on function public.reserve_image_test_attempt() to service_role;
commit;

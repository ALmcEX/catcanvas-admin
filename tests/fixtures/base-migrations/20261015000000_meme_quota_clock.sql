-- Timestamp provider admission after any insert/row-lock wait, including midnight.
begin;
create or replace function public.reserve_meme_attempt() returns void language plpgsql security definer set search_path='' as $$
declare u public.meme_provider_usage; stamp timestamptz; day date; recent timestamptz[];
begin
 insert into public.meme_provider_usage(singleton,usage_date) values(true,(clock_timestamp() at time zone 'America/Los_Angeles')::date) on conflict do nothing;
 select * into u from public.meme_provider_usage where singleton for update;
 stamp:=clock_timestamp(); day:=(stamp at time zone 'America/Los_Angeles')::date;
 select coalesce(array_agg(a),'{}') into recent from unnest(u.recent_attempts) a where a>stamp-interval '1 minute';
 if cardinality(recent)>=10 or (u.usage_date=day and u.attempts>=400) then raise exception 'quotaExceeded'; end if;
 update public.meme_provider_usage set usage_date=day,attempts=case when u.usage_date=day then u.attempts+1 else 1 end,recent_attempts=array_append(recent,stamp) where singleton;
end $$;
commit;

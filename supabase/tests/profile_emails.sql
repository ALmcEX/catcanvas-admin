begin;
insert into auth.users(id,email,raw_app_meta_data) values
 ('ee220000-0000-4000-8000-000000000001','directory-admin@example.test','{"provider":"google"}'),
 ('ee220000-0000-4000-8000-000000000002','directory-member@example.test','{"provider":"google"}'),
 ('ee220000-0000-4000-8000-000000000003',null,'{"provider":"google"}');
insert into auth.identities(id,user_id,provider_id,provider,identity_data) values
 ('ee220000-0000-4000-8000-000000000011','ee220000-0000-4000-8000-000000000001','directory-admin','google','{}'),
 ('ee220000-0000-4000-8000-000000000012','ee220000-0000-4000-8000-000000000002','directory-member','google','{}');
update public.profiles set is_superadmin=true where id='ee220000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"ee220000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"provider":"google"},"amr":[{"method":"oauth"}]}',true);
do $$ declare d jsonb;begin
 d:=public.admin_profiles('ee220000-0000-4000-8000-000000000002');
 if d->'rows'->0->>'email' is distinct from 'directory-member@example.test' then raise exception 'FAIL account email missing';end if;
 d:=public.admin_profiles('DIRECTORY-MEMBER@EXAMPLE.TEST');
 if (d->>'total')::int<>1 or jsonb_array_length(d->'rows')<>1 then raise exception 'FAIL email search/count';end if;
 d:=public.admin_profiles('missing-directory@example.test');
 if (d->>'total')::int<>0 or jsonb_array_length(d->'rows')<>0 then raise exception 'FAIL empty search';end if;
 d:=public.admin_profiles('ee220000-0000-4000-8000-000000000003');
 if jsonb_array_length(d->'rows')<>1 or d->'rows'->0->>'email' is not null then raise exception 'FAIL profile without email';end if;
end $$;
select set_config('request.jwt.claims','{"sub":"ee220000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"provider":"google"},"amr":[{"method":"oauth"}]}',true);
do $$ begin
 begin perform public.admin_profiles('directory-admin');raise exception 'FAIL ordinary email access';exception when insufficient_privilege then null;end;
end $$;
set local role anon;
do $$ begin
 begin perform public.admin_profiles();raise exception 'FAIL anonymous email access';exception when insufficient_privilege then null;end;
end $$;
rollback;
select 'PASS: account emails, case-insensitive search, matching counts, missing-email profiles and ordinary/anonymous denial; rolled back' as result;

begin;
insert into auth.users(id,raw_app_meta_data) values
('ac210000-0000-4000-8000-000000000001','{"provider":"google"}'),
('ac210000-0000-4000-8000-000000000002','{"provider":"google"}');
insert into auth.identities(id,user_id,provider_id,provider,identity_data) values
('ac210000-0000-4000-8000-000000000011','ac210000-0000-4000-8000-000000000001','admin-fixture','google','{}'),
('ac210000-0000-4000-8000-000000000012','ac210000-0000-4000-8000-000000000002','user-fixture','google','{}');
update public.profiles set is_superadmin=true where id='ac210000-0000-4000-8000-000000000001';
insert into public.ai_generations(id,user_id,prompt,system_prompt,title,body,language,provider,model,purpose,meme_template,caption_choices)
values('ac210000-0000-4000-8000-000000000021','ac210000-0000-4000-8000-000000000002','Fixture prompt','test','Fixture','One','en','gemini','gemini-3.1-flash-lite','meme_caption',
'{"id":"405658","name":"Grumpy Cat","description":"Test","width":600,"height":600,"imageUrl":"https://imgflip.com/s/meme/Grumpy-Cat.jpg","sourceUrl":"https://imgflip.com/memetemplate/Grumpy-Cat"}',array['One','Two','Three','Four']);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"ac210000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"provider":"google"}}',true);
do $$ begin
 begin perform public.admin_overview();raise exception 'FAIL non-admin read';exception when insufficient_privilege then null;end;
 begin perform public.admin_profiles();raise exception 'FAIL non-admin profiles';exception when insufficient_privilege then null;end;
 begin perform public.admin_media();raise exception 'FAIL non-admin media';exception when insufficient_privilege then null;end;
 begin perform public.admin_votes();raise exception 'FAIL non-admin votes';exception when insufficient_privilege then null;end;
 begin perform public.admin_media_mutate('create','ac210000-0000-4000-8000-000000000021','Test','Two','');raise exception 'FAIL non-admin mutation';exception when insufficient_privilege then null;end;
 begin update public.profiles set is_superadmin=true where id=auth.uid();raise exception 'FAIL self-promotion';exception when insufficient_privilege then null;end;
 begin insert into public.profiles(id,is_superadmin) values(auth.uid(),true) on conflict(id) do update set is_superadmin=true;raise exception 'FAIL upsert promotion';exception when insufficient_privilege then null;end;
 update public.profiles set first_name='Ordinary editor' where id=auth.uid();
 if not exists(select 1 from public.profiles where id=auth.uid() and first_name='Ordinary editor' and not is_superadmin) then raise exception 'FAIL profile compatibility';end if;
end $$;
select set_config('request.jwt.claims','{"sub":"ac210000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"provider":"google"}}',true);
do $$ declare post uuid;begin
 if not public.is_superadmin() then raise exception 'FAIL administrator';end if;
 perform public.admin_overview();perform public.admin_profiles();perform public.admin_media();perform public.admin_votes();
 post:=public.admin_media_mutate('create','ac210000-0000-4000-8000-000000000021','Admin publication','Two','NYC');
 perform public.admin_media_mutate('update','ac210000-0000-4000-8000-000000000021','Updated','Three','');
 if not exists(select 1 from public.rants where id=post and body='Three') then raise exception 'FAIL update';end if;
 begin perform public.admin_media_mutate('update','ac210000-0000-4000-8000-000000000021','Bad','Invented','');raise exception 'FAIL fabricated caption';exception when raise_exception then if sqlerrm='FAIL fabricated caption' then raise;end if;end;
 perform public.admin_media_mutate('delete','ac210000-0000-4000-8000-000000000021');
 if exists(select 1 from public.rants where id=post) then raise exception 'FAIL delete';end if;
end $$;
reset role;
do $$ begin
 if not exists(select 1 from public.ai_generations where id='ac210000-0000-4000-8000-000000000021' and body='Three' and selected_caption=2) then raise exception 'FAIL preserve source';end if;
end $$;
update public.profiles set is_superadmin=false where id='ac210000-0000-4000-8000-000000000001';
set local role authenticated;
do $$ begin
 begin perform public.admin_overview();raise exception 'FAIL revoked access';exception when insufficient_privilege then null;end;
end $$;
set local role anon;
do $$ begin
 begin perform public.admin_overview();raise exception 'FAIL anonymous';exception when insufficient_privilege then null;end;
end $$;
rollback;
select 'PASS: ordinary profile compatibility, self-promotion rejection, Google admin CRUD, immutable provenance, revoked and anonymous denial; all fixtures rolled back' as result;

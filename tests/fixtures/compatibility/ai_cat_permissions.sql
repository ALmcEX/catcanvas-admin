-- Run after 20261008000004. The transaction rolls back every fixture.
begin;
insert into auth.users(id,email) values
 ('11111111-1111-4111-8111-111111111111','cat-test-a@example.invalid'),
 ('22222222-2222-4222-8222-222222222222','cat-test-b@example.invalid');
insert into storage.objects(bucket_id,name) values('ai-cat-images','11111111-1111-4111-8111-111111111111/test-cat.png');
set local role service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
do $$ declare token uuid; gid uuid; begin
 token:=public.reserve_ai_generation('11111111-1111-4111-8111-111111111111');
 begin
  perform public.finish_ai_cat_image('11111111-1111-4111-8111-111111111111',token,'scene','cat system','en','test-image','22222222-2222-4222-8222-222222222222/foreign.png','image/png','tabby','clay');
  raise exception 'foreign image accepted';
 exception when raise_exception then if sqlerrm<>'invalid generated image' then raise; end if; end;
 gid:=public.finish_ai_cat_image('11111111-1111-4111-8111-111111111111',token,'original cat scene','cat system','en','test-image','11111111-1111-4111-8111-111111111111/test-cat.png','image/png','tabby','clay');
 if not exists(select 1 from public.ai_generations where id=gid and media_type='image' and prompt='original cat scene' and art_style='clay') then raise exception 'image provenance missing'; end if;
 if (select succeeded from public.ai_generation_usage where user_id='11111111-1111-4111-8111-111111111111')<>1 then raise exception 'image quota not committed'; end if;
end $$;
reset role;
set local role anon;
select set_config('request.jwt.claims','{"role":"anon"}',true);
do $$ begin
 if exists(select 1 from storage.objects where bucket_id='ai-cat-images' and name='11111111-1111-4111-8111-111111111111/test-cat.png') then raise exception 'unpublished image leaked'; end if;
 begin perform public.finish_ai_cat_image(gen_random_uuid(),gen_random_uuid(),'x','x','en','x','x','image/png','tabby','clay'); raise exception 'anonymous generation write allowed'; exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}',true);
do $$ begin
 if exists(select 1 from storage.objects where bucket_id='ai-cat-images' and name='11111111-1111-4111-8111-111111111111/test-cat.png') then raise exception 'foreign draft image leaked'; end if;
 if exists(select 1 from public.ai_generations where provider='gemini' and model='test-image') then raise exception 'foreign prompt leaked'; end if;
 begin insert into storage.objects(bucket_id,name) values('ai-cat-images','22222222-2222-4222-8222-222222222222/fake.png'); raise exception 'browser output spoof allowed'; exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',true);
do $$ begin
 if (select count(*) from storage.objects where bucket_id='ai-cat-images' and name='11111111-1111-4111-8111-111111111111/test-cat.png')<>1 then raise exception 'own preview denied'; end if;
 begin perform public.finish_ai_cat_image(gen_random_uuid(),gen_random_uuid(),'x','x','en','x','x','image/png','tabby','clay'); raise exception 'browser generation write allowed'; exception when insufficient_privilege then null; end;
end $$;
insert into public.rants(user_id,title,location,body,generation_id)
select '11111111-1111-4111-8111-111111111111','Test cat','Dorm','My own text',id from public.ai_generations where model='test-image';
do $$ begin
 if not exists(select 1 from public.rants where title='Test cat' and ai_image_path='11111111-1111-4111-8111-111111111111/test-cat.png') then raise exception 'published image association missing'; end if;
end $$;
reset role;
set local role anon;
select set_config('request.jwt.claims','{"role":"anon"}',true);
do $$ begin
 if (select count(*) from storage.objects where bucket_id='ai-cat-images' and name='11111111-1111-4111-8111-111111111111/test-cat.png')<>1 then raise exception 'published image unavailable'; end if;
end $$;
reset role;
rollback;
select 'PASS: draft image privacy, published image visibility, server-only generation writes, ownership, saved prompt/image metadata and atomic quota. All fixtures rolled back.' as result;

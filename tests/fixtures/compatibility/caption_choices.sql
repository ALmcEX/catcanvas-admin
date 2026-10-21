begin;
insert into auth.users(id) values('91919191-9191-4191-8191-919191919191'),('92929292-9292-4292-8292-929292929292');
insert into storage.objects(bucket_id,name) values('caption-photos','91919191-9191-4191-8191-919191919191/93939393-9393-4393-8393-939393939393.png');
set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select set_config('caption_test.gen', public.finish_caption_choices(
 '91919191-9191-4191-8191-919191919191',
 public.reserve_ai_generation('91919191-9191-4191-8191-919191919191'),
 'Lunch on campus','Test system','en','gemini-3.1-flash-lite',
 array['Lunch wins','Nap first','Library later','City tomorrow'],
 '{"id":"uploaded","name":"Your photo","description":"User photo","imageUrl":"","sourceUrl":"","width":1000,"height":750,"storagePath":"91919191-9191-4191-8191-919191919191/93939393-9393-4393-8393-939393939393.png"}'::jsonb
)::text,true);
reset role;
set local role anon;
select set_config('request.jwt.claim.role','anon',true);
do $$ declare denied boolean:=false; begin
 if exists(select 1 from storage.objects where bucket_id='caption-photos') then raise exception 'unpublished photo leaked'; end if;
 begin perform public.publish_caption_choice(current_setting('caption_test.gen')::uuid,1,''); exception when insufficient_privilege then denied:=true; end;
 if not denied then raise exception 'guest published'; end if;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','92929292-9292-4292-8292-929292929292',true);
do $$ declare denied boolean:=false; begin
 begin perform public.publish_caption_choice(current_setting('caption_test.gen')::uuid,1,''); exception when others then denied:=true; end;
 if not denied then raise exception 'other user published'; end if;
 if exists(select 1 from public.ai_generations where id=current_setting('caption_test.gen')::uuid) then raise exception 'private choices leaked'; end if;
end $$;
select set_config('request.jwt.claim.sub','91919191-9191-4191-8191-919191919191',true);
do $$ declare denied boolean:=false; begin
 begin perform public.publish_caption_choice(current_setting('caption_test.gen')::uuid,4,''); exception when others then denied:=true; end;
 if not denied then raise exception 'invalid index accepted'; end if;
end $$;
select public.publish_caption_choice(current_setting('caption_test.gen')::uuid,1,'');
do $$ begin
 if not exists(select 1 from public.cat_feed_page('latest','all',0,true)) then null; end if;
 if not exists(select 1 from public.meme_feed_page('latest','all',0,true) where body='Nap first' and title='AI caption' and template->>'id'='uploaded') then raise exception 'selected caption not published correctly'; end if;
 if not exists(select 1 from public.ai_generations where id=current_setting('caption_test.gen')::uuid and cardinality(caption_choices)=4 and selected_caption=1 and prompt='Lunch on campus') then raise exception 'choices or prompt not retained'; end if;
end $$;
reset role;
set local role anon;
select set_config('request.jwt.claim.role','anon',true);
select set_config('request.jwt.claim.sub','',true);
do $$ begin
 if not exists(select 1 from storage.objects where bucket_id='caption-photos') then raise exception 'published photo not readable'; end if;
end $$;
rollback;
select 'PASS: four choices, selected publication, ownership, private uploads and published photo read; rolled back' as verification;

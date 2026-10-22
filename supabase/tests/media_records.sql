begin;
insert into auth.users(id,raw_app_meta_data) values('cd210000-0000-4000-8000-000000000001','{"provider":"google"}'),('cd210000-0000-4000-8000-000000000002','{"provider":"google"}');
insert into auth.identities(id,user_id,provider_id,provider,identity_data) values('cd210000-0000-4000-8000-000000000011','cd210000-0000-4000-8000-000000000001','crud-admin','google','{}'),('cd210000-0000-4000-8000-000000000012','cd210000-0000-4000-8000-000000000002','crud-member','google','{}');
update public.profiles set is_superadmin=true where id='cd210000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"cd210000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"provider":"google"},"amr":[{"method":"oauth"}]}',true);
do $$ begin
 begin perform public.admin_media_save('{}');raise exception 'FAIL ordinary create';exception when insufficient_privilege then null;end;
 begin perform public.admin_media_delete('cd210000-0000-4000-8000-000000000021');raise exception 'FAIL ordinary delete';exception when insufficient_privilege then null;end;
 begin perform public.admin_media_pending_cleanup();raise exception 'FAIL cleanup leak';exception when insufficient_privilege then null;end;
 begin insert into storage.objects(bucket_id,name) values('ai-cat-images','cd210000-0000-4000-8000-000000000002/test.png');raise exception 'FAIL ordinary upload';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claims','{"sub":"cd210000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"provider":"google"},"amr":[{"method":"oauth"}]}',true);
do $$ declare g uuid; p uuid; result jsonb;begin
 g:=public.admin_media_save('{"kind":"caption","title":"CRUD draft","prompt":"Original prompt","body":"Original imported AI text","model":"Imported source model","attestation":true,"publish":false}');
 if public.admin_media_record(g)->>'post_id' is not null then raise exception 'FAIL draft published';end if;
 perform public.admin_media_save(jsonb_build_object('id',g,'kind','caption','title','Edited draft','prompt','Corrected source prompt','body','Edited text','model','Edited source model','publish',false));
 if public.admin_media_record(g)->>'title'<>'Edited draft' then raise exception 'FAIL draft update';end if;
 perform public.admin_media_save(jsonb_build_object('id',g,'kind','caption','title','Published CRUD','prompt','Corrected source prompt','body','Edited text','model','Edited source model','publish',true));
 p:=(public.admin_media_record(g)->>'post_id')::uuid;
 if p is null then raise exception 'FAIL publish';end if;
 insert into public.rant_votes(rant_id,user_id,value) values(p,auth.uid(),1);
 result:=public.admin_media_delete(g);
 if public.admin_media_record(g) is not null then raise exception 'FAIL source not deleted';end if;
 if exists(select 1 from public.rants where id=p) or exists(select 1 from public.rant_votes where rant_id=p) then raise exception 'FAIL dependent rows';end if;
 g:=public.admin_media_save('{"kind":"caption","title":"Unpublished delete","prompt":"Another prompt","body":"Caption","model":"Source model","attestation":true}');
 perform public.admin_media_delete(g);
 if public.admin_media_record(g) is not null then raise exception 'FAIL draft deletion';end if;
 -- Admin image uploads are restricted to supported buckets and paths.
 insert into storage.objects(bucket_id,name) values('ai-cat-images',auth.uid()::text||'/cd210000-0000-4000-8000-000000000031.png');
 g:=public.admin_media_save(jsonb_build_object('kind','image','title','Imported image','prompt','Source image prompt','body','','model','Source image model','attestation',true,'publish',true,'breed','tabby','style','photo','file',jsonb_build_object('path',auth.uid()::text||'/cd210000-0000-4000-8000-000000000031.png','bucket','ai-cat-images','mime','image/png','width',640,'height',480)));
 if public.admin_asset_unused('ai-cat-images',auth.uid()::text||'/cd210000-0000-4000-8000-000000000031.png') then raise exception 'FAIL referenced asset removable';end if;
 result:=public.admin_media_delete(g);
 if jsonb_array_length(result->'assets')<>1 then raise exception 'FAIL missing cleanup receipt';end if;
 if not public.admin_asset_unused('ai-cat-images',auth.uid()::text||'/cd210000-0000-4000-8000-000000000031.png') then raise exception 'FAIL orphan cleanup denied';end if;
 begin
  perform public.admin_media_mark_clean((result->>'receipt')::uuid);
  raise exception 'FAIL cleaned receipt while asset still exists';
 exception when others then
  if SQLERRM <> 'asset cleanup is not complete' then raise;end if;
 end;
 perform public.admin_media_queue_upload_cleanup('ai-cat-images',auth.uid()::text||'/cd210000-0000-4000-8000-000000000032.png');
 if not exists(select 1 from jsonb_array_elements(public.admin_media_pending_cleanup()) x where x->'assets'->0->>'path'=auth.uid()::text||'/cd210000-0000-4000-8000-000000000032.png') then raise exception 'FAIL compensation not queued';end if;
 -- A publication change made outside the new RPC must invalidate old forms.
 g:=public.admin_media_save('{"kind":"caption","title":"Concurrent draft","prompt":"Original prompt","body":"AI text","model":"Source model","attestation":true,"publish":true}');
 result:=public.admin_media_record(g);
 update public.rants set title='Newer title' where generation_id=g;
 begin
  perform public.admin_media_delete(g,(result->>'version')::integer);
  raise exception 'FAIL stale delete accepted';
 exception when others then
  if SQLERRM <> 'media changed; refresh before deleting' then raise;end if;
 end;
 begin
  perform public.admin_media_save(jsonb_build_object('id',g,'version',(result->>'version')::integer,'kind','caption','title','Stale title','prompt','Prompt','body','Stale body','model','Source model'));
  raise exception 'FAIL stale edit accepted';
 exception when others then
  if SQLERRM <> 'media changed; refresh before saving' then raise;end if;
 end;
 perform public.admin_media_delete(g);
end $$;
reset role;
do $$ begin
 if not exists(select 1 from public.admin_media_audit where before_record->>'title'='CRUD draft' and action='update') then raise exception 'FAIL original provenance not audited';end if;
end $$;
set local role anon;
do $$ begin
 begin perform public.admin_media_save('{}');raise exception 'FAIL anonymous create';exception when insufficient_privilege then null;end;
 begin perform public.admin_media_record('cd210000-0000-4000-8000-000000000021');raise exception 'FAIL anonymous read';exception when insufficient_privilege then null;end;
end $$;
rollback;
select 'PASS: source creation, draft and published updates/deletes, publication cascade, private audit, admin uploads and orphan cleanup; rolled back' as result;

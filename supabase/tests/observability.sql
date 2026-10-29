begin;
insert into auth.users(id,email,raw_app_meta_data) values
('aa770000-0000-4000-8000-000000000001','assignment7-admin@example.test','{"provider":"google"}'),
('aa770000-0000-4000-8000-000000000002','assignment7-member@example.test','{"provider":"google"}');
insert into auth.identities(id,user_id,provider_id,provider,identity_data) values
('aa770000-0000-4000-8000-000000000011','aa770000-0000-4000-8000-000000000001','assignment7-admin','google','{}'),
('aa770000-0000-4000-8000-000000000012','aa770000-0000-4000-8000-000000000002','assignment7-member','google','{}');
update public.profiles set is_superadmin=true where id='aa770000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"aa770000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"provider":"google"},"amr":[{"method":"oauth"}]}',true);
do $$ declare d jsonb; r jsonb; k text; value jsonb; mid uuid; pid uuid;begin
 foreach k in array array['terms','generation-examples','llm-models','llm-providers','allowed-signup-domains','whitelisted-emails'] loop
  value:=case k when 'terms' then '{"term":"Assignment seven","definition":"A glossary entry"}'::jsonb
   when 'generation-examples' then '{"input_prompt":"A sleepy cat","output_text":"Monday again","purpose":"caption_choices"}'::jsonb
   when 'llm-providers' then '{"name":"Test provider","slug":"assignment7-test","website":"https://example.test"}'::jsonb
   when 'llm-models' then jsonb_build_object('name','Test model','model_id','test-model','modality','text','provider_id',(public.admin_observability_list('llm-providers','gemini',0)->'rows'->0->>'id')::uuid)
   when 'allowed-signup-domains' then '{"domain":" EXAMPLE.TEST "}'::jsonb
   else '{"email":" PERSON@OTHER.TEST "}'::jsonb end;
  r:=public.admin_configuration_save(k,value);
  if r->>'id' is null or (r->>'version')::int<>0 then raise exception 'FAIL create %',k;end if;
  d:=public.admin_observability_record(k,(r->>'id')::uuid);
  if d->>'id'<>r->>'id' then raise exception 'FAIL read %',k;end if;
  d:=public.admin_configuration_save(k,value||jsonb_build_object('id',r->>'id','version',0));
  if (d->>'version')::int<>1 then raise exception 'FAIL version %',k;end if;
  begin perform public.admin_configuration_save(k,value||jsonb_build_object('id',r->>'id','version',0));raise exception 'FAIL stale %',k;exception when serialization_failure then null;end;
  if k='allowed-signup-domains' and d->>'domain'<>'example.test' then raise exception 'FAIL normalized domain';end if;
  if k='whitelisted-emails' and d->>'email'<>'person@other.test' then raise exception 'FAIL normalized email';end if;
  perform public.admin_configuration_delete(k,(r->>'id')::uuid,1);
  if public.admin_observability_record(k,(r->>'id')::uuid) is not null then raise exception 'FAIL delete %',k;end if;
 end loop;
 foreach k in array array['prompt-chains','prompt-chain-steps','prompt-chain-mix','generation-requests','llm-responses'] loop
  d:=public.admin_observability_list(k,'',0);
  if not d ? 'rows' or not d ? 'total' then raise exception 'FAIL list %',k;end if;
 end loop;
 begin perform public.admin_observability_list('auth.users');raise exception 'FAIL resource injection';exception when invalid_parameter_value then null;end;
 begin perform public.admin_configuration_save('prompt-chains','{}');raise exception 'FAIL readonly mutation';exception when invalid_parameter_value then null;end;
 begin perform public.admin_configuration_save('terms','{"term":"a","definition":"b","is_superadmin":true}');raise exception 'FAIL extra columns';exception when invalid_parameter_value then null;end;
 begin perform public.admin_configuration_save('allowed-signup-domains','{"domain":"*.example.com"}');raise exception 'FAIL wildcard';exception when check_violation then null;end;
 pid:=(public.admin_observability_list('llm-providers','gemini',0)->'rows'->0->>'id')::uuid;
 begin perform public.admin_configuration_delete('llm-providers',pid,0);raise exception 'FAIL delete referenced provider';exception when foreign_key_violation then null;end;
 mid:=(public.admin_observability_list('prompt-chain-mix')->'rows'->0->>'id')::uuid;
 begin perform public.admin_chain_mix_save(mid,true,50,0);raise exception 'FAIL invalid mix sum';exception when check_violation then null;end;
 perform public.admin_chain_mix_save(mid,false,100,0);
 perform public.admin_chain_mix_save(mid,true,100,1);
 begin perform public.admin_chain_mix_save(mid,true,100,0);raise exception 'FAIL stale mix';exception when serialization_failure then null;end;
end $$;
-- Restricted lists are checked at auth.users creation, and existing users remain.
select public.admin_configuration_save('allowed-signup-domains','{"domain":"example.test"}');
select public.admin_configuration_save('whitelisted-emails','{"email":"special@other.test"}');
reset role;
insert into auth.users(id,email) values('aa770000-0000-4000-8000-000000000003','new@example.test'),('aa770000-0000-4000-8000-000000000004','SPECIAL@OTHER.TEST');
do $$begin
 begin insert into auth.users(id,email) values('aa770000-0000-4000-8000-000000000005','new@sub.example.test');raise exception 'FAIL subdomain signup';exception when check_violation then null;end;
 begin insert into auth.users(id,email) values('aa770000-0000-4000-8000-000000000006','new@blocked.test');raise exception 'FAIL blocked signup';exception when check_violation then null;end;
 if not exists(select 1 from public.profiles where id='aa770000-0000-4000-8000-000000000003') then raise exception 'FAIL profile trigger';end if;
end $$;
insert into public.ai_generations(id,user_id,prompt,system_prompt,title,body,language,provider,model,media_type,image_path,mime_type,cat_breed,art_style) values
('aa770000-0000-4000-8000-000000000021','aa770000-0000-4000-8000-000000000002','Fixture cat','Fixture system','Fixture image','Fixture body','en','gemini','gemini-3.1-flash-lite-image','image','aa770000-0000-4000-8000-000000000002/fixture.png','image/png','orange','photo');
set local role service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
do $$declare r jsonb; rid uuid; gid uuid;begin
 r:=public.begin_generation_request('aa770000-0000-4000-8000-000000000002','caption_choices','A sleepy cat','{"language":"en"}');rid:=(r->>'id')::uuid;
 if r->'chain'->>'code'<>'caption-choices-v1' or r->'chain'->>'model'<>'gemini-3.1-flash-lite' then raise exception 'FAIL registry';end if;
 perform public.record_llm_response(rid,'{"http_status":200,"output_text":"Four real captions","input_tokens":12,"output_tokens":8,"finish_reason":"STOP","duration_ms":100}');
 perform public.record_llm_response(rid,'{"http_status":200,"output_text":"Four real captions","input_tokens":12,"output_tokens":8,"finish_reason":"STOP","duration_ms":100}');
 perform public.finish_generation_request(rid,null,'saveFailed');
 if (select count(*) from public.llm_responses where request_id=rid)<>1 then raise exception 'FAIL duplicate response';end if;
 if (select status from public.generation_requests where id=rid)<>'failed' then raise exception 'FAIL request failure';end if;
 r:=public.begin_generation_request('aa770000-0000-4000-8000-000000000002','cat_image','A cat','{}');rid:=(r->>'id')::uuid;
 perform public.finish_generation_request(rid,'aa770000-0000-4000-8000-000000000021',null);
 if (select status from public.generation_requests where id=rid)<>'succeeded' then raise exception 'FAIL successful media link';end if;
 r:=public.begin_generation_request('aa770000-0000-4000-8000-000000000001','cat_image','A cat','{}');rid:=(r->>'id')::uuid;
 begin perform public.finish_generation_request(rid,'aa770000-0000-4000-8000-000000000021',null);raise exception 'FAIL cross-owner media link';exception when invalid_parameter_value then null;end;
 begin perform public.record_llm_response(rid,'{"api_key":"secret"}');raise exception 'FAIL secret payload';exception when invalid_parameter_value then null;end;
 begin perform public.finish_generation_request(rid,null,null);raise exception 'FAIL invalid success';exception when invalid_parameter_value then null;end;
end $$;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"aa770000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"provider":"google"},"amr":[{"method":"oauth"}]}',true);
do $$declare k text;begin
 foreach k in array array['terms','generation-examples','llm-models','llm-providers','allowed-signup-domains','whitelisted-emails','prompt-chains','prompt-chain-steps','prompt-chain-mix','generation-requests','llm-responses'] loop
  begin perform public.admin_observability_list(k);raise exception 'FAIL ordinary read %',k;exception when insufficient_privilege then null;end;
 end loop;
 begin perform public.admin_configuration_save('terms','{"term":"bad","definition":"bad"}');raise exception 'FAIL ordinary write';exception when insufficient_privilege then null;end;
 begin perform public.begin_generation_request('aa770000-0000-4000-8000-000000000002','caption_choices','input','{}');raise exception 'FAIL client telemetry';exception when insufficient_privilege then null;end;
 begin perform * from public.whitelisted_emails;raise exception 'FAIL direct table read';exception when insufficient_privilege then null;end;
end $$;
set local role anon;
do $$begin
 begin perform public.admin_observability_list('terms');raise exception 'FAIL anonymous read';exception when insufficient_privilege then null;end;
end $$;
rollback;
select 'PASS: Assignment 7 CRUD, normalization, readonly resources, stale updates, mix, signup policy, request logs and access denial; rolled back' as result;

begin;
create table public.llm_providers (
 id uuid primary key default gen_random_uuid(), name text not null check(char_length(btrim(name)) between 1 and 120),
 slug text not null unique check(slug ~ '^[a-z0-9][a-z0-9-]{0,79}$'), website text not null default '' check(website='' or (char_length(website)<=508 and website ~ '^https://[^[:space:]]+$')), description text not null default '' check(char_length(description)<=2000),
 version integer not null default 0, created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table public.llm_models (
 id uuid primary key default gen_random_uuid(),provider_id uuid not null references public.llm_providers(id),
 name text not null check(char_length(btrim(name)) between 1 and 120),model_id text not null check(model_id ~ '^[a-zA-Z0-9][a-zA-Z0-9._/-]{0,119}$'),
 modality text not null check(modality in ('text','image')),description text not null default '' check(char_length(description)<=2000),
 version integer not null default 0,created_at timestamptz not null default now(),updated_at timestamptz not null default now(), unique(provider_id,model_id));
create table public.prompt_chains (
 id uuid primary key default gen_random_uuid(),code text not null unique,name text not null,purpose text not null check(purpose in ('caption_choices','meme_caption','cat_image')),description text not null,implementation_version integer not null default 1,
 created_at timestamptz not null default now());
create table public.prompt_chain_steps (
 id uuid primary key default gen_random_uuid(),chain_id uuid not null references public.prompt_chains(id),sequence integer not null check(sequence>0),
 model_id uuid not null references public.llm_models(id),operation text not null,prompt_template text not null,configuration jsonb not null default '{}',created_at timestamptz not null default now(),unique(chain_id,sequence));
create table public.prompt_chain_mix (
 id uuid primary key default gen_random_uuid(),chain_id uuid not null unique references public.prompt_chains(id),enabled boolean not null default true,weight integer not null default 100 check(weight between 0 and 100),
 version integer not null default 0,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table public.terms (
 id uuid primary key default gen_random_uuid(),term text not null check(char_length(btrim(term)) between 1 and 120),definition text not null check(char_length(btrim(definition)) between 1 and 4000),example text not null default '' check(char_length(example)<=2000),
 version integer not null default 0,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create unique index terms_normalized on public.terms(lower(term));
create table public.ai_generation_examples (
 id uuid primary key default gen_random_uuid(),input_prompt text not null check(char_length(btrim(input_prompt)) between 1 and 4000),output_text text not null check(char_length(btrim(output_text)) between 1 and 8000),
 purpose text not null check(purpose in ('caption_choices','meme_caption','cat_image')),model_id uuid references public.llm_models(id),media_id uuid references public.ai_generations(id) on delete set null,notes text not null default '' check(char_length(notes)<=2000),
 version integer not null default 0,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table public.allowed_signup_domains (
 id uuid primary key default gen_random_uuid(),domain text not null unique check(domain=lower(btrim(domain)) and char_length(domain)<=253 and domain ~ '^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,63}$'),notes text not null default '' check(char_length(notes)<=2000),
 version integer not null default 0,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table public.whitelisted_emails (
 id uuid primary key default gen_random_uuid(),email text not null unique check(email=lower(btrim(email)) and char_length(email)<=254 and email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'),notes text not null default '' check(char_length(notes)<=2000),
 version integer not null default 0,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table public.generation_requests (
 id uuid primary key default gen_random_uuid(),user_id uuid references public.profiles(id) on delete set null,
 purpose text not null,chain_id uuid not null references public.prompt_chains(id),chain_snapshot jsonb not null,prompt text not null check(char_length(prompt) between 1 and 4000),metadata jsonb not null default '{}' check(octet_length(metadata::text)<=4096),
 status text not null default 'pending' check(status in ('pending','succeeded','failed')),generation_id uuid references public.ai_generations(id) on delete set null,error_code text check(char_length(error_code)<=80),
 created_at timestamptz not null default clock_timestamp(),finished_at timestamptz,duration_ms bigint check(duration_ms>=0));
create table public.llm_responses (
 id uuid primary key default gen_random_uuid(),request_id uuid not null references public.generation_requests(id),step_id uuid not null references public.prompt_chain_steps(id),model_id uuid not null references public.llm_models(id),model_snapshot jsonb not null,
 http_status integer check(http_status between 100 and 599),output_text text check(char_length(output_text)<=16000),output_json jsonb check(octet_length(output_json::text)<=24000),
 input_tokens bigint check(input_tokens between 0 and 100000000),output_tokens bigint check(output_tokens between 0 and 100000000),finish_reason text check(char_length(finish_reason)<=80),error_code text check(char_length(error_code)<=80),duration_ms bigint check(duration_ms between 0 and 86400000),truncated boolean not null default false,
 created_at timestamptz not null default clock_timestamp(),unique(request_id,step_id));
create index generation_requests_created on public.generation_requests(created_at desc,id);
create index generation_requests_user on public.generation_requests(user_id,created_at desc);
create index llm_responses_request on public.llm_responses(request_id);

insert into public.llm_providers(name,slug,website,description) values('Google Gemini','gemini','https://ai.google.dev','Provider already used by CatCanvas. Credentials remain in server environment variables.');
insert into public.llm_models(provider_id,name,model_id,modality) select id,'Gemini caption model','gemini-3.1-flash-lite','text' from public.llm_providers where slug='gemini';
insert into public.llm_models(provider_id,name,model_id,modality) select id,'Gemini cat image model','gemini-3.1-flash-lite-image','image' from public.llm_providers where slug='gemini';
insert into public.prompt_chains(code,name,purpose,description) values
 ('caption-choices-v1','Four caption choices','caption_choices','One Gemini call returns four validated distinct captions for a preset or uploaded photo.'),
 ('meme-caption-v1','Single meme caption','meme_caption','One Gemini call returns a validated caption for an existing template.'),
 ('cat-image-v1','Cat image generation','cat_image','One Gemini call returns one validated cat image; existing feature flag and budget still apply.');
insert into public.prompt_chain_steps(chain_id,sequence,model_id,operation,prompt_template,configuration)
 select c.id,1,m.id,c.code,
 case c.purpose when 'caption_choices' then 'Existing generateCaptionChoices implementation: language, template description and optional photo produce four captions. The exact system prompt remains in the versioned creation source and is recorded per response.'
 when 'meme_caption' then 'Existing generateMemeCaption implementation: language, template and scene produce one caption. The exact system prompt remains in the versioned creation source and is recorded per response.'
 else 'Existing generateDraft implementation: breed, style, location and creative prompt produce one cat image. The exact system prompt remains in the versioned creation source and is recorded per response.' end,
 jsonb_build_object('implementation_version',1,'output',case c.purpose when 'caption_choices' then 'four-captions' when 'meme_caption' then 'single-caption' else 'image' end)
 from public.prompt_chains c join public.llm_models m on m.model_id=case when c.purpose='cat_image' then 'gemini-3.1-flash-lite-image' else 'gemini-3.1-flash-lite' end;
insert into public.prompt_chain_mix(chain_id) select id from public.prompt_chains;

create function public.assignment7_revision() returns trigger language plpgsql set search_path='' as $$begin
 new.version:=old.version+1;new.updated_at:=clock_timestamp();return new;end $$;
alter table public.llm_providers enable row level security;
revoke all on table public.llm_providers from public,anon,authenticated,service_role;
grant select on table public.llm_providers to service_role;
alter table public.llm_models enable row level security;
revoke all on table public.llm_models from public,anon,authenticated,service_role;
grant select on table public.llm_models to service_role;
alter table public.prompt_chains enable row level security;
revoke all on table public.prompt_chains from public,anon,authenticated,service_role;
grant select on table public.prompt_chains to service_role;
alter table public.prompt_chain_steps enable row level security;
revoke all on table public.prompt_chain_steps from public,anon,authenticated,service_role;
grant select on table public.prompt_chain_steps to service_role;
alter table public.prompt_chain_mix enable row level security;
revoke all on table public.prompt_chain_mix from public,anon,authenticated,service_role;
grant select on table public.prompt_chain_mix to service_role;
alter table public.terms enable row level security;
revoke all on table public.terms from public,anon,authenticated,service_role;
grant select on table public.terms to service_role;
alter table public.ai_generation_examples enable row level security;
revoke all on table public.ai_generation_examples from public,anon,authenticated,service_role;
grant select on table public.ai_generation_examples to service_role;
alter table public.allowed_signup_domains enable row level security;
revoke all on table public.allowed_signup_domains from public,anon,authenticated,service_role;
grant select on table public.allowed_signup_domains to service_role;
alter table public.whitelisted_emails enable row level security;
revoke all on table public.whitelisted_emails from public,anon,authenticated,service_role;
grant select on table public.whitelisted_emails to service_role;
alter table public.generation_requests enable row level security;
revoke all on table public.generation_requests from public,anon,authenticated,service_role;
grant select on table public.generation_requests to service_role;
alter table public.llm_responses enable row level security;
revoke all on table public.llm_responses from public,anon,authenticated,service_role;
grant select on table public.llm_responses to service_role;
create trigger assignment7_revision before update on public.llm_providers for each row execute function public.assignment7_revision();
create trigger assignment7_revision before update on public.llm_models for each row execute function public.assignment7_revision();
create trigger assignment7_revision before update on public.prompt_chain_mix for each row execute function public.assignment7_revision();
create trigger assignment7_revision before update on public.terms for each row execute function public.assignment7_revision();
create trigger assignment7_revision before update on public.ai_generation_examples for each row execute function public.assignment7_revision();
create trigger assignment7_revision before update on public.allowed_signup_domains for each row execute function public.assignment7_revision();
create trigger assignment7_revision before update on public.whitelisted_emails for each row execute function public.assignment7_revision();

create function public.assignment7_table(p_resource text) returns text language sql immutable set search_path='' as $$
 select case p_resource
 when 'llm-providers' then 'llm_providers' when 'llm-models' then 'llm_models'
 when 'prompt-chains' then 'prompt_chains' when 'prompt-chain-steps' then 'prompt_chain_steps'
 when 'prompt-chain-mix' then 'prompt_chain_mix' when 'terms' then 'terms'
 when 'generation-examples' then 'ai_generation_examples' when 'allowed-signup-domains' then 'allowed_signup_domains'
 when 'whitelisted-emails' then 'whitelisted_emails' when 'generation-requests' then 'generation_requests' when 'llm-responses' then 'llm_responses' end
$$;
create function public.admin_observability_list(p_resource text,p_query text default '',p_page integer default 0) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare t text;rows jsonb;total bigint;q text:=left(coalesce(p_query,''),120);
begin
 perform public.require_superadmin();t:=public.assignment7_table(p_resource);
 if t is null or p_page is null or p_page<0 or p_page>10000 then raise exception 'Invalid resource or page' using errcode='22023';end if;
 execute format('select coalesce(jsonb_agg(x),''[]''::jsonb) from (select * from public.%I r where to_jsonb(r)::text ilike $1 order by created_at desc,id limit 20 offset $2) x',t) into rows using '%'||q||'%',p_page*20;
 execute format('select count(*) from public.%I r where to_jsonb(r)::text ilike $1',t) into total using '%'||q||'%';
 return jsonb_build_object('rows',rows,'total',total);
end $$;
create function public.admin_observability_record(p_resource text,p_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$declare t text;r jsonb;begin
 perform public.require_superadmin();t:=public.assignment7_table(p_resource);if t is null then raise exception 'Invalid resource' using errcode='22023';end if;
 execute format('select to_jsonb(r) from public.%I r where id=$1',t) into r using p_id;return r;
end $$;
create function public.admin_configuration_save(p_resource text,p_record jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare t text;cols text[];defaults jsonb;payload jsonb;result jsonb;rid uuid;rev integer;column_sql text;projection text;
begin
 perform public.require_superadmin();
 if jsonb_typeof(p_record)<>'object' then raise exception 'Invalid record' using errcode='22023';end if;
 t:=public.assignment7_table(p_resource);
 case p_resource
 when 'llm-providers' then cols:=array['name','slug','website','description'];defaults:='{"website":"","description":""}';
 when 'llm-models' then cols:=array['provider_id','name','model_id','modality','description'];defaults:='{"description":""}';
 when 'terms' then cols:=array['term','definition','example'];defaults:='{"example":""}';
 when 'generation-examples' then cols:=array['input_prompt','output_text','purpose','model_id','media_id','notes'];defaults:='{"model_id":null,"media_id":null,"notes":""}';
 when 'allowed-signup-domains' then cols:=array['domain','notes'];defaults:='{"notes":""}';
 when 'whitelisted-emails' then cols:=array['email','notes'];defaults:='{"notes":""}';
 else raise exception 'Read-only or unknown resource' using errcode='22023';end case;
 if exists(select 1 from jsonb_object_keys(p_record) k where k<>all(cols||array['id','version'])) then raise exception 'Unknown field' using errcode='22023';end if;
 payload:=defaults||p_record;rid:=(payload->>'id')::uuid;rev:=(payload->>'version')::integer;
 if p_resource='allowed-signup-domains' then payload:=jsonb_set(payload,'{domain}',to_jsonb(lower(btrim(payload->>'domain'))));end if;
 if p_resource='whitelisted-emails' then payload:=jsonb_set(payload,'{email}',to_jsonb(lower(btrim(payload->>'email'))));end if;
 if rid is not null and rev is null then raise exception 'Version required' using errcode='22023';end if;
 -- Runtime identifiers cannot be changed through descriptive catalog edits.
 if rid is not null and p_resource='llm-providers' and exists(select 1 from public.llm_models where provider_id=rid)
 and (select slug from public.llm_providers where id=rid) is distinct from payload->>'slug' then raise exception 'Provider is referenced' using errcode='23503';end if;
 if rid is not null and p_resource='llm-models' and (exists(select 1 from public.prompt_chain_steps where model_id=rid) or exists(select 1 from public.llm_responses where model_id=rid))
 and exists(select 1 from public.llm_models where id=rid and (model_id is distinct from payload->>'model_id' or provider_id is distinct from (payload->>'provider_id')::uuid or modality is distinct from payload->>'modality')) then raise exception 'Model is referenced' using errcode='23503';end if;
 select string_agg(format('%I',c),','),string_agg(format('x.%I',c),',') into column_sql,projection from unnest(cols)c;
 if rid is null then
 execute format('insert into public.%I (%s) select %s from jsonb_populate_record(null::public.%I,$1) x returning to_jsonb(%I.*)',t,column_sql,projection,t,t) into result using payload;
 else
 execute format('update public.%I as target set (%s)=(select %s from jsonb_populate_record(null::public.%I,$1) x) where target.id=$2 and target.version=$3 returning to_jsonb(target.*)',t,column_sql,projection,t) into result using payload,rid,rev;
 if result is null then raise exception 'Record changed; refresh before saving' using errcode='40001';end if;
 end if;
 return result;
end $$;
create function public.admin_configuration_delete(p_resource text,p_id uuid,p_version integer) returns void
language plpgsql security definer set search_path='' as $$declare t text;n integer;begin
 perform public.require_superadmin();
 if p_resource not in ('llm-providers','llm-models','terms','generation-examples','allowed-signup-domains','whitelisted-emails') then raise exception 'Read-only or unknown resource' using errcode='22023';end if;
 t:=public.assignment7_table(p_resource);
 execute format('delete from public.%I where id=$1 and version=$2',t) using p_id,p_version;get diagnostics n=row_count;
 if n<>1 then raise exception 'Record changed; refresh before deleting' using errcode='40001';end if;
end $$;
create function public.admin_chain_mix_save(p_chain_id uuid,p_enabled boolean,p_weight integer,p_version integer) returns void
language plpgsql security definer set search_path='' as $$declare selected_purpose text;total integer;begin
 perform public.require_superadmin();
 select c.purpose into selected_purpose from public.prompt_chain_mix m join public.prompt_chains c on c.id=m.chain_id where m.id=p_chain_id;
 if selected_purpose is null then raise exception 'Unknown mix' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtext('catcanvas-mix-'||selected_purpose));
 update public.prompt_chain_mix set enabled=p_enabled,weight=p_weight where id=p_chain_id and version=p_version;
 if not found then raise exception 'Mix changed; refresh' using errcode='40001';end if;
 select coalesce(sum(m.weight) filter(where m.enabled),0) into total from public.prompt_chain_mix m join public.prompt_chains c on c.id=m.chain_id where c.purpose=selected_purpose;
 if (exists(select 1 from public.prompt_chain_mix m join public.prompt_chains c on c.id=m.chain_id where c.purpose=selected_purpose and m.enabled) and total<>100) then raise exception 'Active weights must total 100' using errcode='23514';end if;
end $$;

create function public.assignment7_signup_guard() returns trigger language plpgsql security definer set search_path='' as $$declare address text:=lower(btrim(new.email));begin
 if not exists(select 1 from public.allowed_signup_domains) and not exists(select 1 from public.whitelisted_emails) then return new;end if;
 if exists(select 1 from public.whitelisted_emails where email=address) or exists(select 1 from public.allowed_signup_domains where domain=split_part(address,'@',2)) then return new;end if;
 raise exception 'Signup is not allowed for this email address' using errcode='23514';
end $$;
create trigger assignment7_signup_guard before insert on auth.users for each row execute function public.assignment7_signup_guard();

create function public.begin_generation_request(p_user_id uuid,p_purpose text,p_prompt text,p_metadata jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$declare chain jsonb;rid uuid;begin
 if auth.role()<>'service_role' then raise exception 'Service only' using errcode='42501';end if;
 if p_user_id is null or p_prompt is null or char_length(btrim(p_prompt)) not between 1 and 4000 or jsonb_typeof(p_metadata)<>'object' or octet_length(p_metadata::text)>4096
 or exists(select 1 from jsonb_object_keys(p_metadata) k where k not in ('language','template_id','has_photo','breed','style','location')) then raise exception 'Invalid request' using errcode='22023';end if;
 select jsonb_build_object('id',c.id,'code',c.code,'version',c.implementation_version,'step_id',s.id,'model_id',m.id,'model',m.model_id,'provider',p.slug) into chain
 from public.prompt_chains c join public.prompt_chain_mix x on x.chain_id=c.id join public.prompt_chain_steps s on s.chain_id=c.id and s.sequence=1 join public.llm_models m on m.id=s.model_id join public.llm_providers p on p.id=m.provider_id
 where c.purpose=p_purpose and x.enabled and x.weight>0
 and c.implementation_version=1 and s.operation=c.code and p.slug='gemini'
 and c.code=case p_purpose when 'caption_choices' then 'caption-choices-v1' when 'meme_caption' then 'meme-caption-v1' when 'cat_image' then 'cat-image-v1' end
 and m.model_id=case when p_purpose='cat_image' then 'gemini-3.1-flash-lite-image' else 'gemini-3.1-flash-lite' end
 order by -ln(greatest(random(),0.000001))/x.weight limit 1;
 if chain is null then raise exception 'aiUnavailable: no supported active chain' using errcode='22023';end if;
 insert into public.generation_requests(user_id,purpose,chain_id,chain_snapshot,prompt,metadata) values(p_user_id,p_purpose,(chain->>'id')::uuid,chain,btrim(p_prompt),p_metadata) returning id into rid;
 return jsonb_build_object('id',rid,'chain',chain);
end $$;
create function public.record_llm_response(p_request_id uuid,p_response jsonb) returns void
language plpgsql security definer set search_path='' as $$declare r public.generation_requests;begin
 if auth.role()<>'service_role' then raise exception 'Service only' using errcode='42501';end if;
 if jsonb_typeof(p_response)<>'object' or exists(select 1 from jsonb_object_keys(p_response) k where k not in ('http_status','output_text','output_json','input_tokens','output_tokens','finish_reason','error_code','duration_ms','truncated')) then raise exception 'Invalid response fields' using errcode='22023';end if;
 select * into r from public.generation_requests where id=p_request_id;
 if r.id is null then raise exception 'Unknown request' using errcode='22023';end if;
 if p_response ? 'output_json' and (jsonb_typeof(p_response->'output_json')<>'object' or exists(select 1 from jsonb_object_keys(p_response->'output_json') k where k not in ('captions','mime_type','byte_length','system_prompt'))) then raise exception 'Invalid output fields' using errcode='22023';end if;
 insert into public.llm_responses(request_id,step_id,model_id,model_snapshot,http_status,output_text,output_json,input_tokens,output_tokens,finish_reason,error_code,duration_ms,truncated)
 values(r.id,(r.chain_snapshot->>'step_id')::uuid,(r.chain_snapshot->>'model_id')::uuid,r.chain_snapshot,
 (p_response->>'http_status')::integer,p_response->>'output_text',p_response->'output_json',(p_response->>'input_tokens')::bigint,(p_response->>'output_tokens')::bigint,p_response->>'finish_reason',p_response->>'error_code',(p_response->>'duration_ms')::bigint,coalesce((p_response->>'truncated')::boolean,false))
 on conflict(request_id,step_id) do nothing;
end $$;
create function public.finish_generation_request(p_request_id uuid,p_generation_id uuid default null,p_error_code text default null) returns void
language plpgsql security definer set search_path='' as $$declare r public.generation_requests;begin
 if auth.role()<>'service_role' then raise exception 'Service only' using errcode='42501';end if;
 if (p_generation_id is null)=(p_error_code is null) or (p_error_code is not null and p_error_code !~ '^[a-zA-Z][a-zA-Z0-9]{0,79}$') then raise exception 'Provide a result or safe error code' using errcode='22023';end if;
 select * into r from public.generation_requests where id=p_request_id for update;
 if r.id is null then raise exception 'Unknown request' using errcode='22023';end if;
 if r.status<>'pending' then return;end if;
 if p_generation_id is not null and not exists(select 1 from public.ai_generations g where g.id=p_generation_id and g.user_id=r.user_id and g.provider=r.chain_snapshot->>'provider' and g.model=r.chain_snapshot->>'model'
 and ((r.purpose in ('caption_choices','meme_caption') and g.purpose='meme_caption') or (r.purpose='cat_image' and g.media_type='image'))) then raise exception 'Generation does not match request' using errcode='22023';end if;
 update public.generation_requests set status=case when p_error_code is null then 'succeeded' else 'failed' end,generation_id=p_generation_id,error_code=p_error_code,finished_at=clock_timestamp(),duration_ms=greatest(0,extract(epoch from (clock_timestamp()-created_at))*1000)::bigint where id=r.id;
end $$;
revoke all on function public.admin_observability_list(text,text,integer) from public,anon,authenticated,service_role;
grant execute on function public.admin_observability_list(text,text,integer) to authenticated;
revoke all on function public.admin_observability_record(text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.admin_observability_record(text,uuid) to authenticated;
revoke all on function public.admin_configuration_save(text,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.admin_configuration_save(text,jsonb) to authenticated;
revoke all on function public.admin_configuration_delete(text,uuid,integer) from public,anon,authenticated,service_role;
grant execute on function public.admin_configuration_delete(text,uuid,integer) to authenticated;
revoke all on function public.admin_chain_mix_save(uuid,boolean,integer,integer) from public,anon,authenticated,service_role;
grant execute on function public.admin_chain_mix_save(uuid,boolean,integer,integer) to authenticated;
revoke all on function public.begin_generation_request(uuid,text,text,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.begin_generation_request(uuid,text,text,jsonb) to service_role;
revoke all on function public.record_llm_response(uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.record_llm_response(uuid,jsonb) to service_role;
revoke all on function public.finish_generation_request(uuid,uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.finish_generation_request(uuid,uuid,text) to service_role;
revoke all on function public.assignment7_revision() from public,anon,authenticated,service_role;
revoke all on function public.assignment7_signup_guard() from public,anon,authenticated,service_role;
revoke all on function public.assignment7_table(text) from public,anon,authenticated,service_role;
commit;

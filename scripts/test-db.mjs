process.on("uncaughtException", (e) => {
  console.error(e.message, e.detail || "", e.where || "");
  process.exit(1);
});
import { PGlite } from "@electric-sql/pglite";
import { readFile, readdir } from "node:fs/promises";
const db = new PGlite();
await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;
create schema auth;create schema storage;
create table auth.users(id uuid primary key,email text,raw_app_meta_data jsonb default '{}');
create table auth.identities(id uuid primary key,user_id uuid references auth.users(id),provider_id text,provider text,identity_data jsonb);
create function auth.jwt() returns jsonb language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;
create function auth.uid() returns uuid language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claim.sub',true),''),auth.jwt()->>'sub')::uuid$$;
create function auth.role() returns text language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claim.role',true),''),auth.jwt()->>'role',current_user)$$;
grant usage on schema auth,storage,public to anon,authenticated,service_role;
grant execute on all functions in schema auth to anon,authenticated,service_role;
create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text references storage.buckets(id),name text,owner uuid);
alter table storage.objects enable row level security;
grant select,insert,update,delete on storage.objects to anon,authenticated,service_role;
create function storage.foldername(text) returns text[] language sql immutable as $$select (string_to_array($1,'/'))[1:array_length(string_to_array($1,'/'),1)-1]$$;
alter default privileges in schema public grant all on tables to anon,authenticated,service_role;
`);
for (const f of (await readdir("tests/fixtures/base-migrations")).sort())
  await db.exec(await readFile(`tests/fixtures/base-migrations/${f}`, "utf8"));
await db.exec(
  await readFile("supabase/migrations/20261021000000_admin.sql", "utf8"),
);
await db.exec(
  await readFile(
    "supabase/migrations/20261021000001_admin_library_scope.sql",
    "utf8",
  ),
);
const r = await db.exec(
  await readFile("supabase/tests/admin_permissions.sql", "utf8"),
);
console.log(r.at(-1).rows);
for (const f of (await readdir("tests/fixtures/compatibility")).sort()) {
  await db.exec(await readFile(`tests/fixtures/compatibility/${f}`, "utf8"));
  console.log("PASS compatibility:", f);
}
await db.close();

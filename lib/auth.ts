import "server-only";
import { redirect } from "next/navigation";
import { supabase } from "./supabase";
import { isAdmin } from "./access";
export async function requireAdmin() {
  const client = await supabase();
  const {
    data: { user },
    error,
  } = await client.auth.getUser();
  if (error || !user) redirect("/login");
  const { data: profile, error: profileError } = await client
    .from("profiles")
    .select("id,first_name,last_name,is_superadmin")
    .eq("id", user.id)
    .maybeSingle();
  if (profileError || !isAdmin(user, profile)) redirect("/access-denied");
  return { client, user, profile: profile! };
}

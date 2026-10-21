"use server";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { supabase } from "@/lib/supabase";
export async function login() {
  const h = await headers();
  const origin = h.get("origin");
  if (!origin) redirect("/login?error=origin");
  const { data, error } = await (
    await supabase()
  ).auth.signInWithOAuth({
    provider: "google",
    options: {
      redirectTo: `${origin}/auth/callback`,
      queryParams: { prompt: "select_account" },
    },
  });
  if (error || !data.url) redirect("/login?error=oauth");
  redirect(data.url);
}
export async function logout() {
  await (await supabase()).auth.signOut();
  redirect("/login");
}

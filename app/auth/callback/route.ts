import { NextResponse, type NextRequest } from "next/server";
import { supabase } from "@/lib/supabase";
export async function GET(request: NextRequest) {
  const code = request.nextUrl.searchParams.get("code");
  if (!code)
    return NextResponse.redirect(new URL("/login?error=callback", request.url));
  const { error } = await (await supabase()).auth.exchangeCodeForSession(code);
  return NextResponse.redirect(
    new URL(error ? "/login?error=callback" : "/", request.url),
  );
}

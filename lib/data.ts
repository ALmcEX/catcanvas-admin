import "server-only";
import { requireAdmin } from "./auth";
export async function adminData<T>(
  name: string,
  args: Record<string, unknown> = {},
) {
  const { client } = await requireAdmin();
  const { data, error } = await client.rpc(name, args);
  if (error)
    throw new Error(
      "Unable to load admin data. Check the database migration and your access, then retry.",
    );
  return data as T;
}
export function date(value: string) {
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    timeZone: "America/New_York",
  }).format(new Date(value));
}

import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";
type Cleanup = { id: string; assets: { bucket: string; path: string }[] };
export async function cleanupMediaFiles(client: SupabaseClient) {
  const { data, error } = await client.rpc("admin_media_pending_cleanup");
  if (error) return false;
  let complete = true;
  for (const item of data as Cleanup[]) {
    let removed = true;
    for (const asset of item.assets) {
      const { data: unused, error: checkError } = await client.rpc(
        "admin_asset_unused",
        { p_bucket: asset.bucket, p_path: asset.path },
      );
      if (checkError || !unused) {
        removed = false;
        break;
      }
      const { error: removeError } = await client.storage
        .from(asset.bucket)
        .remove([asset.path]);
      if (removeError) {
        removed = false;
        break;
      }
    }
    if (removed) {
      const { error: markError } = await client.rpc("admin_media_mark_clean", {
        p_receipt: item.id,
      });
      if (markError) removed = false;
    }
    if (!removed) complete = false;
  }
  return complete;
}

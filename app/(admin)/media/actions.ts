"use server";
import { requireAdmin } from "@/lib/auth";
import { parseMedia } from "@/lib/validation";
import { revalidatePath } from "next/cache";
export type MutationState = { error?: string; success?: string };
export async function saveMedia(
  _state: MutationState,
  form: FormData,
): Promise<MutationState> {
  const { client } = await requireAdmin();
  try {
    const fields = parseMedia(Object.fromEntries(form));
    const action = form.get("operation");
    if (!["create", "update", "delete"].includes(String(action)))
      return { error: "Invalid operation." };
    if (action === "delete" && form.get("confirmation") !== "DELETE")
      return { error: "Type DELETE to confirm removal of this publication." };
    const { error } = await client.rpc("admin_media_mutate", {
      p_action: action,
      p_id: fields.id,
      p_title: fields.title,
      p_body: fields.body,
      p_location: fields.location,
    });
    if (error)
      return {
        error:
          "This change could not be saved. The record may have changed, or your access may have been revoked. Refresh and try again.",
      };
    revalidatePath("/");
    revalidatePath("/media");
    revalidatePath("/ratings");
    return {
      success:
        action === "delete"
          ? "Publication removed. The original AI generation is preserved."
          : action === "create"
            ? "Published to the community."
            : "Publication updated.",
    };
  } catch (e) {
    return {
      error: e instanceof Error ? e.message : "Unable to save this change.",
    };
  }
}

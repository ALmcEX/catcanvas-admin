"use server";
import { requireAdmin } from "@/lib/auth";
import {
  getResource,
  normalizeConfiguration,
  parseMix,
  version,
} from "@/lib/admin-resources";
import { uuid } from "@/lib/validation";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
export type ConfigurationState = { error?: string };
function failure(code?: string) {
  if (code === "40001")
    return "This record changed. Refresh the page before trying again.";
  if (code === "23503")
    return "This record is referenced, or a selected related record no longer exists. Review its references before saving or deleting.";
  if (code === "23505") return "An entry with this value already exists.";
  if (code === "23514" || code === "23502" || code === "22P02")
    return "Check the required fields and allowed values. Enabled mix weights must total 100%.";
  return "Unable to save this change. Check your access and retry.";
}
export async function saveConfiguration(
  _state: ConfigurationState,
  form: FormData,
): Promise<ConfigurationState> {
  const { client } = await requireAdmin();
  const resource = String(form.get("resource") ?? "");
  if (!getResource(resource)?.editable)
    return { error: "This resource is read-only." };
  try {
    const input: Record<string, unknown> = {};
    for (const f of getResource(resource)!.fields)
      input[f.key] = form.get(f.key);
    if (form.get("id")) {
      input.id = form.get("id");
      input.version = form.get("version");
    }
    const record = normalizeConfiguration(resource, input);
    const { error } = await client.rpc("admin_configuration_save", {
      p_resource: resource,
      p_record: record,
    });
    if (error) return { error: failure(error.code) };
  } catch (e) {
    return { error: e instanceof Error ? e.message : "Invalid record." };
  }
  revalidatePath(`/${resource}`);
  redirect(`/${resource}?notice=saved`);
}
export async function deleteConfiguration(
  _state: ConfigurationState,
  form: FormData,
): Promise<ConfigurationState> {
  const { client } = await requireAdmin();
  const resource = String(form.get("resource") ?? "");
  if (!getResource(resource)?.editable)
    return { error: "This resource is read-only." };
  try {
    if (form.get("confirmation") !== "DELETE")
      return { error: "Type DELETE to confirm this deletion." };
    const { error } = await client.rpc("admin_configuration_delete", {
      p_resource: resource,
      p_id: uuid(form.get("id")),
      p_version: version(form.get("version")),
    });
    if (error) return { error: failure(error.code) };
  } catch (e) {
    return { error: e instanceof Error ? e.message : "Invalid record." };
  }
  revalidatePath(`/${resource}`);
  redirect(`/${resource}?notice=deleted`);
}
export async function saveMix(
  _state: ConfigurationState,
  form: FormData,
): Promise<ConfigurationState> {
  const { client } = await requireAdmin();
  try {
    const value = parseMix(Object.fromEntries(form));
    const { error } = await client.rpc("admin_chain_mix_save", {
      p_chain_id: value.id,
      p_version: value.version,
      p_weight: value.weight,
      p_enabled: value.enabled,
    });
    if (error) return { error: failure(error.code) };
  } catch (e) {
    return { error: e instanceof Error ? e.message : "Invalid allocation." };
  }
  revalidatePath("/prompt-chain-mix");
  redirect("/prompt-chain-mix?notice=saved");
}

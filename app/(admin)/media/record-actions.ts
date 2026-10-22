"use server";
import { requireAdmin } from "@/lib/auth";
import { parseRecord } from "@/lib/media-record";
import { inspectImage } from "@/lib/image-input";
import { cleanupMediaFiles } from "@/lib/media-cleanup";
import { uuid } from "@/lib/validation";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
export type RecordState = { error?: string };
export async function saveRecord(
  _state: RecordState,
  form: FormData,
): Promise<RecordState> {
  const { client, user } = await requireAdmin();
  let uploaded: { bucket: string; path: string } | undefined;
  let notice = "saved";
  try {
    const input = parseRecord(Object.fromEntries(form));
    let owner = user.id;
    if (input.id) {
      const { data: current, error } = await client.rpc("admin_media_record", {
        p_id: input.id,
      });
      if (error || !current)
        throw new Error("Media no longer exists. Refresh the library.");
      const version = Number(form.get("version"));
      if (
        !Number.isSafeInteger(version) ||
        version < 0 ||
        version !== current.version
      )
        throw new Error("This media changed. Refresh before saving.");
      owner = current.user_id;
    }
    const file = form.get("file");
    let asset;
    if (file instanceof File && file.size) {
      if (form.get("attestation") !== "on")
        throw new Error(
          "Confirm that the replacement file is existing AI-generated content.",
        );
      if (input.kind === "text")
        throw new Error(
          "Legacy text records do not support image replacement.",
        );
      if (file.size > 3 * 1024 * 1024)
        throw new Error("Choose an image no larger than 3 MB.");
      const buffer = Buffer.from(await file.arrayBuffer());
      const image = await inspectImage(buffer, file.type);
      const bucket =
        input.kind === "image" ? "ai-cat-images" : "caption-photos";
      const path = `${owner}/${crypto.randomUUID()}.${image.extension}`;
      const { error } = await client.storage
        .from(bucket)
        .upload(path, buffer, { contentType: image.mime, upsert: false });
      if (error)
        throw new Error("Image upload failed. No media record was changed.");
      uploaded = { bucket, path };
      asset = {
        bucket,
        path,
        mime: image.mime,
        width: image.width,
        height: image.height,
      };
    }
    if (!input.id && input.kind === "image" && !asset)
      throw new Error("Choose the existing AI image to import.");
    const { error } = await client.rpc("admin_media_save", {
      p_record: {
        ...input,
        version: input.id ? Number(form.get("version")) : undefined,
        attestation: form.get("attestation") === "on",
        file: asset ?? null,
      },
    });
    if (error)
      throw new Error(
        error.message.includes("media changed")
          ? "This media changed. Refresh before saving."
          : "Unable to save this record. Check its fields and your current access.",
      );
    notice = input.id ? "saved" : "created";
  } catch (error) {
    if (uploaded) {
      const { error: queueError } = await client.rpc(
        "admin_media_queue_upload_cleanup",
        {
          p_bucket: uploaded.bucket,
          p_path: uploaded.path,
        },
      );
      if (queueError)
        return {
          error:
            "The record was not saved. Upload cleanup could not be queued; contact the database owner before retrying.",
        };
      if (!(await cleanupMediaFiles(client)))
        return {
          error:
            "The record was not saved. Upload cleanup is queued; use Retry file cleanup in the media library.",
        };
    }
    return {
      error:
        error instanceof Error ? error.message : "Unable to save this record.",
    };
  }
  if (!(await cleanupMediaFiles(client))) notice = "cleanup";
  revalidatePath("/");
  revalidatePath("/media");
  revalidatePath("/ratings");
  revalidatePath("/profiles");
  redirect(`/media?notice=${notice}`);
}
export async function deleteRecord(
  _state: RecordState,
  form: FormData,
): Promise<RecordState> {
  const { client } = await requireAdmin();
  try {
    const id = uuid(form.get("id"));
    const version = Number(form.get("version"));
    if (!Number.isSafeInteger(version) || version < 0)
      throw new Error("Refresh before deleting this record.");
    if (form.get("confirmation") !== "DELETE")
      throw new Error("Type DELETE to confirm full media deletion.");
    const { error } = await client.rpc("admin_media_delete", {
      p_id: id,
      p_version: version,
    });
    if (error)
      throw new Error(
        "The record could not be deleted. It may have changed; refresh and try again.",
      );
  } catch (error) {
    return {
      error:
        error instanceof Error
          ? error.message
          : "Unable to delete this record.",
    };
  }
  const complete = await cleanupMediaFiles(client);
  revalidatePath("/");
  revalidatePath("/media");
  revalidatePath("/ratings");
  revalidatePath("/profiles");
  redirect(`/media?notice=${complete ? "deleted" : "cleanup"}`);
}
export async function retryCleanup() {
  const { client } = await requireAdmin();
  const complete = await cleanupMediaFiles(client);
  revalidatePath("/media");
  redirect(`/media?notice=${complete ? "cleaned" : "cleanup"}`);
}

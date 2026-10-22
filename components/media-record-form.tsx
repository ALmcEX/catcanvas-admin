"use client";
import { useActionState, useState } from "react";
import {
  saveRecord,
  deleteRecord,
  type RecordState,
} from "@/app/(admin)/media/record-actions";
import type { Media } from "@/lib/types";
export function MediaRecordForm({ media: m }: { media?: Media }) {
  const [kind, setKind] = useState(
    m
      ? m.media_type === "image"
        ? "image"
        : m.purpose === "meme_caption"
          ? "caption"
          : "text"
      : "image",
  );
  const [state, action, pending] = useActionState<RecordState, FormData>(
    saveRecord,
    {},
  );
  const [fileChosen, setFileChosen] = useState(false);
  return (
    <form action={action} className="record-form">
      <input type="hidden" name="id" value={m?.id ?? ""} />
      <input type="hidden" name="version" value={m?.version ?? 0} />
      {!m ? (
        <label>
          Media type
          <select
            name="kind"
            value={kind}
            onChange={(e) => setKind(e.target.value)}
          >
            <option value="image">AI-generated image</option>
            <option value="caption">AI-generated caption</option>
          </select>
        </label>
      ) : (
        <input type="hidden" name="kind" value={kind} />
      )}
      <label>
        Title
        <input
          name="title"
          defaultValue={m?.title ?? ""}
          maxLength={120}
          required
        />
      </label>
      <label>
        Source prompt
        <textarea
          name="prompt"
          defaultValue={m?.prompt ?? ""}
          maxLength={1000}
          rows={3}
          required
        />
      </label>
      <label>
        Source model / AI tool
        <input
          name="model"
          defaultValue={m?.model ?? ""}
          maxLength={120}
          required
          placeholder="The model that produced this content"
        />
      </label>
      {m && m.provider !== "admin_import" && (
        <p className="muted">
          Original API model is retained unless you import a replacement file.
          Changes are recorded in the private audit log.
        </p>
      )}
      <label>
        {kind === "image" ? "Public image description" : "AI text / caption"}
        {kind === "image" && <span className="muted"> optional</span>}
        <textarea
          name="body"
          defaultValue={m?.body ?? ""}
          maxLength={kind === "caption" ? 300 : kind === "image" ? 1000 : 3000}
          rows={3}
          required={kind !== "image"}
        />
      </label>
      {kind !== "text" && (
        <label>
          {kind === "image"
            ? m
              ? "Replace image (optional)"
              : "AI image file"
            : "Caption photo (optional; otherwise uses Grumpy Cat template)"}
          <input
            type="file"
            name="file"
            accept="image/png,image/jpeg,image/webp"
            required={!m && kind === "image"}
            onChange={(e) => setFileChosen(!!e.target.files?.length)}
          />
          <span className="muted">
            PNG, JPEG or WebP · maximum 3 MB · one frame
          </span>
        </label>
      )}
      {kind === "image" && !m && (
        <div className="field-grid">
          <label>
            Cat breed
            <select name="breed" defaultValue="orange">
              {[
                "orange",
                "tabby",
                "ragdoll",
                "british",
                "tuxedo",
                "calico",
              ].map((v) => (
                <option key={v}>{v}</option>
              ))}
            </select>
          </label>
          <label>
            Art style
            <select name="style" defaultValue="photo">
              {["photo", "illustration", "clay"].map((v) => (
                <option key={v}>{v}</option>
              ))}
            </select>
          </label>
        </div>
      )}
      <label>
        Location <span className="muted">optional</span>
        <input
          name="location"
          defaultValue={m?.location ?? ""}
          maxLength={120}
        />
      </label>
      {m?.post_id ? (
        <>
          <input type="hidden" name="publish" value="on" />
          <p className="muted">
            This media is published. Saving updates the community work, too.
          </p>
        </>
      ) : (
        <label className="check-label">
          <input type="checkbox" name="publish" />
          Publish to the community now
        </label>
      )}
      {(!m || fileChosen) && (
        <label className="check-label">
          <input type="checkbox" name="attestation" required />I confirm this is
          existing AI-generated content and the source details are accurate.
        </label>
      )}
      {!m && (
        <p className="muted">
          Imports are marked “Imported AI media.” This action does not call or
          charge an AI provider.
        </p>
      )}
      {state.error && (
        <p className="notice" role="alert">
          {state.error}
        </p>
      )}
      <button className="button" disabled={pending}>
        {pending ? "Saving…" : m ? "Save media record" : "Create media record"}
      </button>
    </form>
  );
}
export function MediaRecordDelete({ media: m }: { media: Media }) {
  const [open, setOpen] = useState(false);
  const [state, action, pending] = useActionState<RecordState, FormData>(
    deleteRecord,
    {},
  );
  return (
    <div className="full-delete">
      <button
        type="button"
        className="text-button"
        onClick={() => setOpen(!open)}
      >
        {open ? "Cancel full deletion" : "Delete media record"}
      </button>
      {open && (
        <form action={action} className="delete-notice">
          <strong>Delete “{m.title}” completely?</strong>
          <p>
            This removes the AI media record
            {m.post_id ? ", its community publication" : ""}, {m.votes} votes
            and {m.comments} comments. Unused image files will be removed. A
            private audit snapshot is retained. This action cannot be undone in
            the app.
          </p>
          <input type="hidden" name="id" value={m.id} />
          <input type="hidden" name="version" value={m.version} />
          <label>
            Type DELETE to confirm
            <input
              name="confirmation"
              required
              pattern="DELETE"
              autoComplete="off"
            />
          </label>
          {state.error && <p role="alert">{state.error}</p>}
          <button className="button danger" disabled={pending}>
            {pending ? "Deleting…" : "Permanently delete media"}
          </button>
        </form>
      )}
    </div>
  );
}

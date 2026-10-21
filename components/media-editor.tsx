"use client";
import { useActionState, useState } from "react";
import { saveMedia, type MutationState } from "@/app/(admin)/media/actions";
import type { Media } from "@/lib/types";
export function MediaEditor({ media: m }: { media: Media }) {
  const [open, setOpen] = useState(false),
    [deleting, setDeleting] = useState(false);
  const [state, action, pending] = useActionState<MutationState, FormData>(
    saveMedia,
    {},
  );
  return (
    <div className="editor">
      <button
        className="button small secondary"
        onClick={() => {
          setOpen(!open);
          setDeleting(false);
        }}
      >
        {open ? "Close" : m.post_id ? "Manage ↗" : "Publish ↗"}
      </button>
      {open && (
        <div className="editor-panel">
          <h3>
            {m.post_id ? "Edit publication" : "Publish original AI media"}
          </h3>
          <p className="muted">
            The original prompt and generated asset remain preserved.
          </p>
          <form action={action}>
            <input type="hidden" name="id" value={m.id} />
            <input
              type="hidden"
              name="operation"
              value={deleting ? "delete" : m.post_id ? "update" : "create"}
            />
            <label>
              Title
              <input
                name="title"
                defaultValue={m.title}
                maxLength={120}
                required
              />
            </label>
            <label>
              Caption
              {m.purpose === "meme_caption" ? (
                m.caption_choices ? (
                  <select name="body" defaultValue={m.body}>
                    {m.caption_choices.map((c, i) => (
                      <option key={i} value={c}>
                        {i + 1}. {c}
                      </option>
                    ))}
                  </select>
                ) : (
                  <textarea
                    name="body"
                    defaultValue={m.generated_body}
                    readOnly
                  />
                )
              ) : (
                <textarea
                  name="body"
                  defaultValue={
                    m.media_type === "image" && !m.post_id ? "" : m.body
                  }
                  maxLength={1000}
                  rows={3}
                />
              )}
            </label>
            <label>
              Location <span className="muted">optional</span>
              <input
                name="location"
                defaultValue={m.location}
                maxLength={120}
              />
            </label>
            {deleting && (
              <div className="delete-notice">
                <strong>Remove “{m.title}” from the community?</strong>
                <p>
                  This also removes {m.votes} votes and {m.comments} comments on
                  this publication. The AI source is preserved. This cannot be
                  undone.
                </p>
                <label>
                  Type DELETE to confirm
                  <input
                    name="confirmation"
                    required
                    pattern="DELETE"
                    autoComplete="off"
                  />
                </label>
              </div>
            )}
            {state.error && (
              <p className="notice" role="alert">
                {state.error}
              </p>
            )}
            {state.success && (
              <p className="success" role="status">
                {state.success}
              </p>
            )}
            <div className="form-actions">
              <button
                className={deleting ? "button danger" : "button"}
                disabled={pending}
              >
                {pending
                  ? "Saving…"
                  : deleting
                    ? "Remove publication"
                    : m.post_id
                      ? "Save changes"
                      : "Publish media"}
              </button>
              {m.post_id && (
                <button
                  type="button"
                  className="text-button"
                  onClick={() => setDeleting(!deleting)}
                >
                  {deleting ? "Cancel removal" : "Delete publication"}
                </button>
              )}
            </div>
          </form>
        </div>
      )}
    </div>
  );
}

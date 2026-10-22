"use client";
import { useState } from "react";
import type { Media } from "@/lib/types";
import { MediaRecordForm, MediaRecordDelete } from "./media-record-form";
export function MediaEditor({ media: m }: { media: Media }) {
  const [open, setOpen] = useState(false);
  return (
    <div className="editor">
      <button className="button small secondary" onClick={() => setOpen(!open)}>
        {open
          ? "Close editor"
          : m.post_id
            ? "Edit media ↗"
            : "Edit / publish draft ↗"}
      </button>
      {open && (
        <div className="editor-panel">
          <h3>{m.post_id ? "Edit published media" : "Edit media draft"}</h3>
          <MediaRecordForm media={m} />
        </div>
      )}
      <MediaRecordDelete media={m} />
    </div>
  );
}

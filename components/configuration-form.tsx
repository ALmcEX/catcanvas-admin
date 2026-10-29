"use client";
import { useActionState } from "react";
import { resources, type AdminRow } from "@/lib/admin-resources";
import {
  saveConfiguration,
  deleteConfiguration,
  saveMix,
} from "@/app/(admin)/configuration-actions";
export type ReferenceOptions = Record<string, { id: string; label: string }[]>;
export function ConfigurationForm({
  resource,
  record,
  options = {},
}: {
  resource: string;
  record?: AdminRow;
  options?: ReferenceOptions;
}) {
  const [state, action, pending] = useActionState(saveConfiguration, {});
  const config = resources[resource];
  return (
    <form action={action} className="record-form config-form">
      <input type="hidden" name="resource" value={resource} />
      {record && (
        <>
          <input type="hidden" name="id" value={record.id} />
          <input type="hidden" name="version" value={record.version ?? 0} />
        </>
      )}
      {config.fields.map((f) => (
        <label key={f.key}>
          {f.label}
          {!f.required && <span className="muted"> optional</span>}
          {f.kind === "textarea" ? (
            <textarea
              name={f.key}
              defaultValue={String(record?.[f.key] ?? "")}
              maxLength={f.max}
              required={f.required}
              rows={3}
            />
          ) : f.kind === "select" ? (
            <select
              name={f.key}
              defaultValue={String(record?.[f.key] ?? f.options?.[0] ?? "")}
              required={f.required}
            >
              {f.options?.map((v) => (
                <option key={v} value={v}>
                  {v.replaceAll("_", " ")}
                </option>
              ))}
            </select>
          ) : (
            <input
              name={f.key}
              defaultValue={String(record?.[f.key] ?? "")}
              type={
                f.kind === "email" ? "email" : f.kind === "url" ? "url" : "text"
              }
              maxLength={f.max}
              required={f.required}
              list={
                f.reference
                  ? `${resource}-${record?.id ?? "new"}-${f.key}`
                  : undefined
              }
              placeholder={
                f.kind === "uuid"
                  ? "Select a suggestion or paste an existing ID"
                  : undefined
              }
            />
          )}
          {f.reference && (
            <datalist id={`${resource}-${record?.id ?? "new"}-${f.key}`}>
              {options[f.reference]?.map((o) => (
                <option key={o.id} value={o.id}>
                  {o.label}
                </option>
              ))}
            </datalist>
          )}
        </label>
      ))}
      {state.error && (
        <p className="notice" role="alert">
          {state.error}
        </p>
      )}
      <button className="button" disabled={pending}>
        {pending ? "Saving…" : record ? "Save changes" : "Create record"}
      </button>
    </form>
  );
}
export function ConfigurationDelete({
  resource,
  record,
}: {
  resource: string;
  record: AdminRow;
}) {
  const [state, action, pending] = useActionState(deleteConfiguration, {});
  return (
    <details className="delete-notice">
      <summary>Delete this record</summary>
      <p>
        Remove this specific record permanently. Referenced providers and models
        cannot be deleted. For signup lists, removing the last entries from both
        lists makes future signup unrestricted.
      </p>
      <form action={action} className="record-form">
        <input type="hidden" name="resource" value={resource} />
        <input type="hidden" name="id" value={record.id} />
        <input type="hidden" name="version" value={record.version ?? 0} />
        <label>
          Type DELETE to confirm
          <input
            name="confirmation"
            pattern="DELETE"
            required
            autoComplete="off"
          />
        </label>
        {state.error && (
          <p role="alert" className="notice">
            {state.error}
          </p>
        )}
        <button className="button danger" disabled={pending}>
          {pending ? "Deleting…" : "Permanently delete record"}
        </button>
      </form>
    </details>
  );
}
export function MixForm({ record }: { record: AdminRow }) {
  const [state, action, pending] = useActionState(saveMix, {});
  return (
    <form action={action} className="record-form mix-form">
      <input type="hidden" name="id" value={record.id} />
      <input type="hidden" name="version" value={record.version ?? 0} />
      <label className="check-label">
        <input
          name="enabled"
          type="checkbox"
          defaultChecked={record.enabled === true}
        />
        Enabled
      </label>
      <label>
        Allocation weight (%)
        <input
          type="number"
          name="weight"
          min={0}
          max={100}
          step={1}
          defaultValue={Number(record.weight)}
          required
        />
      </label>
      <p className="muted">
        One deployed variant per purpose. An enabled variant uses 100%; disable
        it to pause that path.
      </p>
      {state.error && (
        <p role="alert" className="notice">
          {state.error}
        </p>
      )}
      <button className="button small" disabled={pending}>
        {pending ? "Saving…" : "Save allocation"}
      </button>
    </form>
  );
}

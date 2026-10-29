import Link from "next/link";
import { notFound } from "next/navigation";
import { adminData } from "@/lib/data";
import {
  getResource,
  relationHref,
  type AdminRow,
} from "@/lib/admin-resources";
import { referenceOptions } from "@/lib/admin-reference-options";
import {
  ConfigurationForm,
  ConfigurationDelete,
} from "@/components/configuration-form";
import { PageHeading } from "@/components/ui";
export default async function ResourceDetail({
  params,
}: {
  params: Promise<{ resource: string; id: string }>;
}) {
  const { resource, id } = await params;
  const config = getResource(resource);
  if (!config || !/^[a-f0-9]{8}-[a-f0-9-]{27}$/i.test(id)) notFound();
  const row = await adminData<AdminRow | null>("admin_observability_record", {
    p_resource: resource,
    p_id: id,
  });
  if (!row) notFound();
  const options = config.editable ? await referenceOptions(resource) : {};
  const steps =
    resource === "prompt-chains"
      ? await adminData<{ rows: AdminRow[] }>("admin_observability_list", {
          p_resource: "prompt-chain-steps",
          p_query: id,
        })
      : null;
  const responses =
    resource === "generation-requests"
      ? await adminData<{ rows: AdminRow[] }>("admin_observability_list", {
          p_resource: "llm-responses",
          p_query: id,
        })
      : null;
  return (
    <>
      <PageHeading
        kicker="CATCANVAS / RECORD DETAILS"
        title={config.title}
        description={config.description}
      >
        <Link className="button secondary" href={`/${resource}`}>
          ← All records
        </Link>
      </PageHeading>
      <section className="panel record-details">
        <h2>Record details</h2>
        <dl className="detail-grid">
          {Object.entries(row).map(([key, value]) => (
            <div key={key}>
              <dt>{key.replaceAll("_", " ")}</dt>
              <dd>
                {value == null ? (
                  "Not recorded"
                ) : relationHref(resource, key, value) ? (
                  <Link href={relationHref(resource, key, value)!}>
                    {String(value)} ↗
                  </Link>
                ) : key === "generation_id" && typeof value === "string" ? (
                  <Link href={`/media?q=${value}`}>View generated media ↗</Link>
                ) : typeof value === "object" ? (
                  <pre>{JSON.stringify(value, null, 2)}</pre>
                ) : (
                  String(value)
                )}
              </dd>
            </div>
          ))}
        </dl>
      </section>
      {steps && (
        <section className="panel record-details">
          <h2>Chain steps</h2>
          {steps.rows.map((s) => (
            <article key={s.id}>
              <h3>
                {String(s.sequence)}. {String(s.operation)}
              </h3>
              <p>{String(s.prompt_template)}</p>
              <p>
                <Link href={`/llm-models/${s.model_id}`}>View model ↗</Link> ·{" "}
                <Link href={`/prompt-chain-steps/${s.id}`}>
                  Full step details ↗
                </Link>
              </p>
            </article>
          ))}
        </section>
      )}
      {responses && (
        <section className="panel record-details">
          <h2>Provider responses</h2>
          {responses.rows.length ? (
            responses.rows.map((r) => (
              <p key={r.id}>
                <Link href={`/llm-responses/${r.id}`}>
                  View response ·{" "}
                  {r.http_status == null
                    ? "No HTTP status"
                    : `HTTP ${r.http_status}`}{" "}
                  ↗
                </Link>
              </p>
            ))
          ) : (
            <p className="muted">
              No provider response was recorded. The request may not have
              reached the provider, or recording is incomplete.
            </p>
          )}
        </section>
      )}
      {config.editable && (
        <section className="panel record-details">
          <h2>Edit record</h2>
          <ConfigurationForm
            resource={resource}
            record={row}
            options={options}
          />
          <ConfigurationDelete resource={resource} record={row} />
        </section>
      )}
    </>
  );
}

import Link from "next/link";
import { notFound } from "next/navigation";
import { adminData } from "@/lib/data";
import { getResource, type AdminRow } from "@/lib/admin-resources";
import { referenceOptions } from "@/lib/admin-reference-options";
import { pagination } from "@/lib/validation";
import { PageHeading, Search, Pager, Empty } from "@/components/ui";
import { ConfigurationForm, MixForm } from "@/components/configuration-form";
const label = (s: string) => s.replaceAll("_", " ");
export default async function ResourcePage({
  params,
  searchParams,
}: {
  params: Promise<{ resource: string }>;
  searchParams: Promise<{ q?: string; page?: string; notice?: string }>;
}) {
  const { resource } = await params;
  const config = getResource(resource);
  if (!config) notFound();
  const p = await searchParams,
    page = pagination(p.page),
    q = (p.q ?? "").slice(0, 120);
  const d = await adminData<{ rows: AdminRow[]; total: number }>(
    "admin_observability_list",
    { p_resource: resource, p_query: q, p_page: page },
  );
  const options = config.editable ? await referenceOptions(resource) : {};
  const chainRows =
    resource === "prompt-chain-mix"
      ? await adminData<{ rows: AdminRow[] }>("admin_observability_list", {
          p_resource: "prompt-chains",
        })
      : null;
  return (
    <>
      <PageHeading
        kicker="CATCANVAS / ADMINISTRATION"
        title={config.title}
        description={config.description}
      />
      {p.notice && ["saved", "deleted"].includes(p.notice) && (
        <p className="success" role="status">
          {p.notice === "saved" ? "Changes saved." : "Record deleted."}
        </p>
      )}
      {config.editable && (
        <details className="panel create-panel">
          <summary>+ Create {config.title.toLowerCase()} record</summary>
          <ConfigurationForm resource={resource} options={options} />
        </details>
      )}
      <section className="panel">
        <div className="toolbar">
          <h2>
            {config.title} <span className="count">{d.total}</span>
          </h2>
          <Search
            query={q}
            placeholder={`Search ${config.title.toLowerCase()}`}
          />
        </div>
        {d.rows.length ? (
          resource === "prompt-chain-mix" ? (
            <div className="configuration-cards">
              {d.rows.map((r) => (
                <article className="config-card" key={`${r.id}-${r.version}`}>
                  <h3>
                    {String(
                      chainRows?.rows.find((c) => c.id === r.chain_id)?.name ??
                        "Generation chain",
                    )}
                  </h3>
                  <Link href={`/prompt-chains/${r.chain_id}`}>
                    View chain ↗
                  </Link>
                  <MixForm record={r} />
                </article>
              ))}
            </div>
          ) : (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    {config.columns.map((c) => (
                      <th key={c}>{label(c)}</th>
                    ))}
                    <th>Details</th>
                  </tr>
                </thead>
                <tbody>
                  {d.rows.map((r) => (
                    <tr key={r.id}>
                      {config.columns.map((c) => (
                        <td className="resource-cell" key={c}>
                          {r[c] == null ? (
                            <span className="muted">Not recorded</span>
                          ) : typeof r[c] === "object" ? (
                            JSON.stringify(r[c])
                          ) : (
                            String(r[c])
                          )}
                        </td>
                      ))}
                      <td>
                        <Link
                          className="text-button"
                          href={`/${resource}/${r.id}`}
                        >
                          {config.editable ? "View / edit" : "View"} ↗
                        </Link>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )
        ) : (
          <Empty
            title="No records yet"
            description="Records appear here as they are created. No demonstration data has been added."
          />
        )}
        <Pager page={page} total={d.total} query={q} />
      </section>
    </>
  );
}

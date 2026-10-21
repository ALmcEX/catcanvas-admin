import { adminData, date } from "@/lib/data";
import type { Profile } from "@/lib/types";
import { pagination } from "@/lib/validation";
import { PageHeading, Search, Pager, Empty } from "@/components/ui";
export default async function Profiles({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; page?: string }>;
}) {
  const p = await searchParams;
  const page = pagination(p.page),
    q = (p.q ?? "").slice(0, 120);
  const d = await adminData<{ rows: Profile[]; total: number }>(
    "admin_profiles",
    { p_query: q, p_page: page },
  );
  return (
    <>
      <PageHeading
        kicker="THE PEOPLE BEHIND THE PIXELS"
        title="Creative company"
        description="Meet the people making CatCanvas their own."
      >
        <span className="pill">Read-only directory</span>
      </PageHeading>
      <section className="panel">
        <div className="toolbar">
          <h2>
            Profiles <span className="count">{d.total}</span>
          </h2>
          <Search query={q} placeholder="Search name or profile ID" />
        </div>
        {d.rows.length ? (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>MEMBER</th>
                  <th>JOINED</th>
                  <th>CREATIONS</th>
                  <th>VOTES</th>
                  <th>ACCESS</th>
                </tr>
              </thead>
              <tbody>
                {d.rows.map((r) => (
                  <tr key={r.id}>
                    <td>
                      <div className="member">
                        <span className="avatar">
                          {(r.first_name || "?")[0]}
                        </span>
                        <div>
                          <strong>
                            {[r.first_name, r.last_name]
                              .filter(Boolean)
                              .join(" ") || "Unnamed member"}
                          </strong>
                          <small className="mono">{r.id}</small>
                        </div>
                      </div>
                    </td>
                    <td>{date(r.created_at)}</td>
                    <td>{r.generations}</td>
                    <td>{r.votes}</td>
                    <td>
                      <span className={r.is_superadmin ? "pill green" : "pill"}>
                        {r.is_superadmin ? "Superadmin" : "Member"}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <Empty
            title="No profiles found"
            description="Try another name or profile ID."
          />
        )}
        <Pager page={page} total={d.total} query={q} />
      </section>
    </>
  );
}

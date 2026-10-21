import { adminData, date } from "@/lib/data";
import type { Vote } from "@/lib/types";
import { pagination } from "@/lib/validation";
import { PageHeading, Pager, Empty } from "@/components/ui";
export default async function Ratings({
  searchParams,
}: {
  searchParams: Promise<{ page?: string }>;
}) {
  const p = await searchParams,
    page = pagination(p.page);
  const d = await adminData<{ rows: Vote[]; total: number }>("admin_votes", {
    p_page: page,
  });
  return (
    <>
      <PageHeading
        kicker="EVERY REACTION TELLS A STORY"
        title="A show of hands"
        description="An honest look at what resonates with the community."
      >
        <span className="pill">Read-only vote ledger</span>
      </PageHeading>
      <section className="panel">
        <div className="toolbar">
          <h2>
            Votes & ratings <span className="count">{d.total}</span>
          </h2>
          <span className="muted">One current vote per member per work</span>
        </div>
        {d.rows.length ? (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>REACTION</th>
                  <th>WORK</th>
                  <th>MEMBER</th>
                  <th>DATE</th>
                </tr>
              </thead>
              <tbody>
                {d.rows.map((r) => (
                  <tr key={r.id}>
                    <td>
                      <span
                        className={
                          r.value === 1 ? "reaction up" : "reaction down"
                        }
                      >
                        {r.value === 1 ? "↑ Upvote" : "↓ Downvote"}
                      </span>
                    </td>
                    <td>
                      <strong>{r.title}</strong>
                      <small className="mono">{r.rant_id}</small>
                    </td>
                    <td>
                      {r.voter || "Unnamed member"}
                      <small className="mono">{r.user_id}</small>
                    </td>
                    <td>{date(r.created_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <Empty
            title="Quiet for now"
            description="Real community votes will appear here as they happen."
          />
        )}
        <Pager page={page} total={d.total} />
      </section>
    </>
  );
}

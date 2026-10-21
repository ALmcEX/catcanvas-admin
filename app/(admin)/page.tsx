import { adminData } from "@/lib/data";
import type { Overview } from "@/lib/types";
import { PageHeading, Empty } from "@/components/ui";
import Link from "next/link";
export default async function OverviewPage() {
  const d = await adminData<Overview>("admin_overview");
  const conversion = d.generations
    ? Math.round((d.published / d.generations) * 100)
    : 0;
  const approval = d.votes ? Math.round((d.upvotes / d.votes) * 100) : 0;
  const max = Math.max(
    1,
    ...d.activity.flatMap((a) => [a.generations, a.votes]),
  );
  return (
    <>
      <PageHeading
        kicker="YOUR COMMUNITY, IN FOCUS"
        title="The bigger picture"
        description="A pulse check on what’s being made, shared, and loved."
      >
        <span className="date-chip">↻ Live database</span>
      </PageHeading>
      <section className="stats-grid">
        {[
          ["Community members", d.users, "REGISTERED PROFILES", "♧"],
          ["AI creations", d.generations, "IDEAS BROUGHT TO LIFE", "✳"],
          ["Published works", d.published, "OUT IN THE WORLD", "▧"],
          ["Votes cast", d.votes, "COMMUNITY REACTIONS", "⇅"],
        ].map(([label, value, note, icon], i) => (
          <article className={`stat stat-${i}`} key={label}>
            <div>
              <span>{label}</span>
              <span className="stat-icon">{icon}</span>
            </div>
            <strong>{Number(value).toLocaleString("en-US")}</strong>
            <small>{note}</small>
          </article>
        ))}
      </section>
      <div className="overview-grid">
        <section className="panel activity">
          <div className="panel-heading">
            <div>
              <span className="eyebrow">THE CREATIVE RHYTHM</span>
              <h2>Small ideas. Daily momentum.</h2>
            </div>
            <span className="muted">Last 14 days · ET</span>
          </div>
          <div className="legend">
            <span>
              <i />
              Creations
            </span>
            <span>
              <i />
              Votes
            </span>
          </div>
          <div
            className="chart"
            role="img"
            aria-label="Daily generations and votes over the last fourteen days"
          >
            {d.activity.map((a) => (
              <div className="chart-column" key={a.day}>
                <div className="bar-pair">
                  <div
                    className="bar creation"
                    style={{ height: `${(a.generations / max) * 100}%` }}
                    title={`${a.day}: ${a.generations} creations`}
                  />
                  <div
                    className="bar vote"
                    style={{ height: `${(a.votes / max) * 100}%` }}
                    title={`${a.day}: ${a.votes} votes`}
                  />
                </div>
                <small>{a.day.slice(5).replace("-", "/")}</small>
              </div>
            ))}
          </div>
          <details className="chart-data">
            <summary>View exact daily counts</summary>
            <table>
              <thead>
                <tr>
                  <th>Day</th>
                  <th>Creations</th>
                  <th>Votes</th>
                </tr>
              </thead>
              <tbody>
                {d.activity.map((a) => (
                  <tr key={a.day}>
                    <td>{a.day}</td>
                    <td>{a.generations}</td>
                    <td>{a.votes}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </details>
        </section>
        <section className="panel conversion">
          <span className="eyebrow">FROM IDEA TO AUDIENCE</span>
          <h2>The publishing gap.</h2>
          <div
            className="ring"
            style={{ "--progress": `${conversion}%` } as React.CSSProperties}
          >
            <div>
              <strong>{conversion}%</strong>
              <span>published</span>
            </div>
          </div>
          <p>
            <b>{d.published}</b> of <b>{d.generations}</b> creations made it to
            the community.
          </p>
          <span className="metric-note">
            Drafts count as creative work, too.
          </span>
        </section>
      </div>
      <div className="lower-grid">
        <section className="panel">
          <div className="panel-heading">
            <div>
              <span className="eyebrow">A LITTLE LOVE, A LITTLE DEBATE</span>
              <h2>The community mood.</h2>
            </div>
            <span className="tiny-icon">↗</span>
          </div>
          <div className="mood-number">
            {d.votes ? `${approval}%` : "—"}
            <span>positive reactions</span>
          </div>
          <div className="sentiment">
            <span style={{ width: `${approval}%` }} />
          </div>
          <div className="split">
            <span>
              <i className="positive" /> {d.upvotes} upvotes
            </span>
            <span>
              <i className="negative" /> {d.downvotes} downvotes
            </span>
          </div>
          <div className="media-mix">
            <span>
              <b>{d.images}</b> AI images
            </span>
            <span>
              <b>{d.captions}</b> AI captions
            </span>
          </div>
        </section>
        <section className="panel">
          <div className="panel-heading">
            <div>
              <span className="eyebrow">THE CONVERSATION STARTERS</span>
              <h2>Beautifully divisive.</h2>
            </div>
            <span className="pill">2+ votes</span>
          </div>
          {d.divisive.length ? (
            <ol className="rank-list">
              {d.divisive.map((r, i) => (
                <li key={r.id}>
                  <span className="rank">0{i + 1}</span>
                  <div>
                    <strong>{r.title}</strong>
                    <small>
                      {r.votes} votes · {r.disagreement}% minority share
                    </small>
                  </div>
                  <span>⇅</span>
                </li>
              ))}
            </ol>
          ) : (
            <Empty
              title="No split decisions yet"
              description="Works with at least two votes will appear here. A 50% minority share means an even split."
            />
          )}
        </section>
      </div>
      <section className="panel spotlight">
        <div>
          <span className="eyebrow">WHAT’S GETTING NOTICED</span>
          <h2>The attention list.</h2>
        </div>
        {d.leaders.length ? (
          <div className="attention-list">
            {d.leaders.map((r, i) => (
              <div key={r.id}>
                <span className="rank">0{i + 1}</span>
                <strong>{r.title}</strong>
                <span>
                  {r.upvotes} ↑ / {r.downvotes} ↓
                </span>
                <b>{r.votes} votes</b>
              </div>
            ))}
          </div>
        ) : (
          <p className="muted">
            The first community vote will start this list.
          </p>
        )}
        <Link className="text-link" href="/ratings">
          Explore all reactions ↗
        </Link>
      </section>
    </>
  );
}

/* eslint-disable @next/next/no-img-element */
import { adminData, date } from "@/lib/data";
import { requireAdmin } from "@/lib/auth";
import type { Media } from "@/lib/types";
import { pagination } from "@/lib/validation";
import { PageHeading, Search, Pager, Empty } from "@/components/ui";
import { MediaEditor } from "@/components/media-editor";
export default async function MediaPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; page?: string }>;
}) {
  const p = await searchParams,
    page = pagination(p.page),
    q = (p.q ?? "").slice(0, 120);
  const d = await adminData<{ rows: Media[]; total: number }>("admin_media", {
    p_query: q,
    p_page: page,
  });
  const { client } = await requireAdmin();
  await Promise.all(
    d.rows.map(async (m) => {
      if (m.media_type === "image" && m.image_path) {
        const { data } = await client.storage
          .from("ai-cat-images")
          .createSignedUrl(m.image_path, 120);
        m.preview = data?.signedUrl;
      } else if (m.meme_template?.storagePath) {
        const { data } = await client.storage
          .from("caption-photos")
          .createSignedUrl(m.meme_template.storagePath, 120);
        m.preview = data?.signedUrl;
      } else if (
        m.meme_template?.imageUrl &&
        /^https:\/\/(i\.imgflip\.com|imgflip\.com)\//.test(
          m.meme_template.imageUrl,
        )
      )
        m.preview = m.meme_template.imageUrl;
    }),
  );
  return (
    <>
      <PageHeading
        kicker="MADE BY AI. CURATED BY YOU."
        title="The creative archive"
        description="Explore original generations, publish drafts, and care for the collection."
      >
        <span className="pill">Original sources preserved</span>
      </PageHeading>
      <section className="panel">
        <div className="toolbar">
          <h2>
            Media library <span className="count">{d.total}</span>
          </h2>
          <Search query={q} placeholder="Search title, prompt or media ID" />
        </div>
        <div className="library-note">
          <span>↗</span>Create a publication from an existing AI draft below.
          Editing a caption keeps its original AI choices; removing a
          publication preserves its source generation.
        </div>
        {d.rows.length ? (
          <div className="media-list">
            {d.rows.map((m) => (
              <article
                className="media-row"
                key={`${m.id}-${m.post_id}-${m.body}-${m.title}`}
              >
                <div className="media-preview">
                  {m.preview ? (
                    <img src={m.preview} alt={m.title} loading="lazy" />
                  ) : (
                    <span>{m.media_type === "image" ? "▧" : "Aa"}</span>
                  )}
                </div>
                <div className="media-info">
                  <div className="split">
                    <span className="eyebrow">
                      {m.media_type === "image"
                        ? "AI IMAGE"
                        : m.purpose === "meme_caption"
                          ? "AI CAPTION"
                          : "AI TEXT"}{" "}
                      / {date(m.created_at)}
                    </span>
                    <span className={m.post_id ? "pill green" : "pill"}>
                      {m.post_id ? "Published" : "Draft"}
                    </span>
                  </div>
                  <h3>{m.title}</h3>
                  <p className="caption">{m.body || "No public caption"}</p>
                  <details>
                    <summary>Generation details</summary>
                    <dl>
                      <dt>Original prompt</dt>
                      <dd>{m.prompt}</dd>
                      <dt>Model</dt>
                      <dd>{m.model || "Not recorded"}</dd>
                      <dt>Generation ID</dt>
                      <dd className="mono">{m.id}</dd>
                      <dt>Creator ID</dt>
                      <dd className="mono">{m.user_id}</dd>
                    </dl>
                  </details>
                  <div className="media-meta">
                    <span>{m.votes} votes</span>
                    <span>{m.comments} comments</span>
                  </div>
                  <MediaEditor media={m} />
                </div>
              </article>
            ))}
          </div>
        ) : (
          <Empty
            title="An open canvas"
            description="AI media from the creation app will appear here. No sample content has been added."
          />
        )}
        <Pager page={page} total={d.total} query={q} />
      </section>
    </>
  );
}

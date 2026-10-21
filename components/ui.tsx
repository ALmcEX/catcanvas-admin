import Link from "next/link";
export function PageHeading({
  kicker,
  title,
  description,
  children,
}: {
  kicker: string;
  title: string;
  description: string;
  children?: React.ReactNode;
}) {
  return (
    <div className="page-heading">
      <div>
        <span className="eyebrow">{kicker}</span>
        <h1>
          {title}
          <span className="orange-dot">.</span>
        </h1>
        <p>{description}</p>
      </div>
      {children}
    </div>
  );
}
export function Search({
  query,
  placeholder,
}: {
  query: string;
  placeholder: string;
}) {
  return (
    <form className="search">
      <span>⌕</span>
      <input
        name="q"
        defaultValue={query}
        placeholder={placeholder}
        aria-label={placeholder}
      />
      <button>Search</button>
    </form>
  );
}
export function Pager({
  page,
  total,
  query = "",
}: {
  page: number;
  total: number;
  query?: string;
}) {
  const max = Math.max(1, Math.ceil(total / 20));
  return (
    <div className="pager">
      <span>
        {total} records · Page {page + 1} of {max}
      </span>
      <div>
        {page > 0 && (
          <Link href={`?page=${page - 1}&q=${encodeURIComponent(query)}`}>
            ← Previous
          </Link>
        )}
        {(page + 1) * 20 < total && (
          <Link href={`?page=${page + 1}&q=${encodeURIComponent(query)}`}>
            Next →
          </Link>
        )}
      </div>
    </div>
  );
}
export function Empty({
  title,
  description,
}: {
  title: string;
  description: string;
}) {
  return (
    <div className="empty">
      <span>↗</span>
      <h3>{title}</h3>
      <p>{description}</p>
    </div>
  );
}

"use client";
import Link from "next/link";
export default function ErrorPage({ reset }: { reset: () => void }) {
  return (
    <section className="panel empty">
      <span>↻</span>
      <h1>We couldn’t load this view.</h1>
      <p>
        The database may be unavailable, or your access may have changed.
        <br />
        No incomplete data is shown.
      </p>
      <button className="button" onClick={reset}>
        Try again
      </button>
      <Link className="text-link" href="/login">
        Return to sign in
      </Link>
    </section>
  );
}

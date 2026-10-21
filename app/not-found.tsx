import Link from "next/link";
export default function NotFound() {
  return (
    <main className="standalone">
      <span className="brand-icon">c.</span>
      <h1>Nothing on this canvas.</h1>
      <Link className="button" href="/">
        Return to workspace ↗
      </Link>
    </main>
  );
}

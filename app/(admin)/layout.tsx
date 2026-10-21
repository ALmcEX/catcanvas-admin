import Link from "next/link";
import { requireAdmin } from "@/lib/auth";
import { Nav } from "@/components/nav";
import { logout } from "@/app/login/actions";
export const dynamic = "force-dynamic";
export default async function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const { user, profile } = await requireAdmin();
  const name =
    [profile.first_name, profile.last_name].filter(Boolean).join(" ") ||
    "Administrator";
  return (
    <div className="shell">
      <aside className="sidebar">
        <Link href="/" className="brand">
          <span className="brand-icon">c.</span>CatCanvas
        </Link>
        <span className="workspace-label">THE CONTROL ROOM</span>
        <Nav />
        <div className="sidebar-note">
          <span>✳</span>
          <p>
            Great communities
            <br />
            are thoughtfully curated.
          </p>
          <small>A little care goes a long way.</small>
        </div>
        <div className="identity">
          <span className="avatar">{name[0].toUpperCase()}</span>
          <div>
            <strong>{name}</strong>
            <small>Superadmin</small>
          </div>
          <form action={logout}>
            <button aria-label="Sign out" title="Sign out">
              ↪
            </button>
          </form>
        </div>
      </aside>
      <div className="workspace">
        <header className="topbar">
          <span>
            WORKSPACE <b>/</b> <strong>Administration</strong>
          </span>
          <span className="session-status">
            <i />
            Google session verified
          </span>
        </header>
        <main className="content">{children}</main>
        <footer className="footer">
          <span>CATCANVAS / A SPACE FOR CREATIVE CURIOSITY</span>
          <span>Private workspace · {user.email}</span>
        </footer>
      </div>
    </div>
  );
}

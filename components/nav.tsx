"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
export function Nav() {
  const path = usePathname();
  return (
    <nav aria-label="Admin navigation">
      {[
        ["/", "◫", "Overview"],
        ["/profiles", "♧", "Profiles"],
        ["/media", "▧", "Media library"],
        ["/ratings", "⇅", "Votes & ratings"],
      ].map(([href, icon, label]) => (
        <Link
          key={href}
          href={href}
          className={path === href ? "nav-item active" : "nav-item"}
          aria-current={path === href ? "page" : undefined}
        >
          <span>{icon}</span>
          {label}
          <span className="nav-arrow">↗</span>
        </Link>
      ))}
    </nav>
  );
}

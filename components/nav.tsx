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
        ["/prompt-chains", "↳", "Prompt chains"],
        ["/prompt-chain-mix", "≋", "Chain mix"],
        ["/generation-requests", "↗", "Generation requests"],
        ["/llm-responses", "≡", "LLM responses"],
        ["/terms", "Aa", "Terms"],
        ["/generation-examples", "◇", "AI examples"],
        ["/llm-models", "◉", "LLM models"],
        ["/llm-providers", "⌘", "LLM providers"],
        ["/allowed-signup-domains", "◎", "Signup domains"],
        ["/whitelisted-emails", "✉", "Whitelisted emails"],
      ].map(([href, icon, label]) => (
        <Link
          key={href}
          href={href}
          className={
            path === href || (href !== "/" && path.startsWith(href + "/"))
              ? "nav-item active"
              : "nav-item"
          }
          aria-current={
            path === href || (href !== "/" && path.startsWith(href + "/"))
              ? "page"
              : undefined
          }
        >
          <span>{icon}</span>
          {label}
          <span className="nav-arrow">↗</span>
        </Link>
      ))}
    </nav>
  );
}

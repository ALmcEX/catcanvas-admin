import { login } from "./actions";
export default async function Login({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const p = await searchParams;
  return (
    <main className="login">
      <div className="login-art">
        <div className="brand">
          <span className="brand-icon">c.</span> CatCanvas{" "}
          <span className="admin-tag">ADMIN</span>
        </div>
        <div>
          <span className="eyebrow">BEHIND THE CANVAS</span>
          <h1>
            A little order.
            <br />A lot of creativity.
          </h1>
          <p>
            A private space to understand your community,
            <br />
            curate the good stuff, and keep creativity moving.
          </p>
          <div className="orb">
            <span>✳</span>
            <span className="orb-caption">MAKE ROOM FOR THE UNEXPECTED.</span>
          </div>
        </div>
        <span className="login-foot">THE CONTROL ROOM / EST. 2026</span>
      </div>
      <section className="login-panel">
        <span className="secure-badge">● RESTRICTED WORKSPACE</span>
        <h2>Welcome backstage.</h2>
        <p>
          Sign in with your Google account to access the CatCanvas control room.
        </p>
        {p.error && (
          <div className="notice">
            Sign-in could not be completed. Please try again.
          </div>
        )}
        <form action={login}>
          <button className="google-button">
            <svg width="20" height="20" viewBox="0 0 24 24" aria-hidden="true">
              <path
                fill="#4285F4"
                d="M21.8 12.2c0-.7-.1-1.4-.2-2.2H12v4h5.5a4.7 4.7 0 0 1-2 3v2.5h3.3c1.9-1.8 3-4.3 3-7.3Z"
              />
              <path
                fill="#34A853"
                d="M12 22c2.7 0 5-.9 6.8-2.5L15.5 17c-.9.6-2 .9-3.5.9-2.7 0-5-1.8-5.8-4.3H2.8v2.6A10 10 0 0 0 12 22Z"
              />
              <path
                fill="#FBBC05"
                d="M6.2 13.6a6 6 0 0 1 0-3.2V7.8H2.8a10 10 0 0 0 0 8.4l3.4-2.6Z"
              />
              <path
                fill="#EA4335"
                d="M12 6.1c1.5 0 2.8.5 3.8 1.5l2.9-2.9A9.6 9.6 0 0 0 12 2a10 10 0 0 0-9.2 5.8l3.4 2.6A6.1 6.1 0 0 1 12 6.1Z"
              />
            </svg>
            Continue with Google <span>↗</span>
          </button>
        </form>
        <p className="fine-print">
          Access is limited to approved superadmins.
          <br />
          Signing in does not automatically grant access.
        </p>
        <div className="login-rule" />
        <small>
          CATCANVAS ADMINISTRATION
          <br />
          <span>Google authentication · Database-enforced access</span>
        </small>
      </section>
    </main>
  );
}

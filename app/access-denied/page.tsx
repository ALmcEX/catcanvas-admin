import { logout } from "../login/actions";
export default function Denied() {
  return (
    <main className="standalone">
      <span className="brand-icon">c.</span>
      <span className="eyebrow">ACCESS RESTRICTED</span>
      <h1>This room is for admins.</h1>
      <p>
        Your Google account does not currently have administrator access.
        <br />
        Ask the database owner to review your profile permission.
      </p>
      <form action={logout}>
        <button className="button">Sign out & use another account ↗</button>
      </form>
    </main>
  );
}

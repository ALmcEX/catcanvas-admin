type IdentityUser = {
  id: string;
  app_metadata?: { provider?: string };
  identities?: { provider: string }[];
} | null;
export function isAdmin(
  user: IdentityUser,
  profile: { id?: unknown; is_superadmin?: unknown } | null,
): boolean {
  return (
    !!user &&
    profile?.id === user.id &&
    profile?.is_superadmin === true &&
    user.app_metadata?.provider === "google" &&
    !!user.identities?.some((i) => i.provider === "google")
  );
}

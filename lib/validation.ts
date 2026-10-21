export function uuid(value: unknown): string {
  if (
    typeof value !== "string" ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
      value,
    )
  )
    throw new Error("Choose a valid media record.");
  return value;
}
export function parseMedia(input: Record<string, unknown>) {
  const id = uuid(input.id);
  const title = typeof input.title === "string" ? input.title.trim() : "";
  const body = typeof input.body === "string" ? input.body.trim() : "";
  const location =
    typeof input.location === "string" ? input.location.trim() : "";
  if (
    !title ||
    Array.from(title).length > 120 ||
    Array.from(body).length > 1000 ||
    Array.from(location).length > 120
  )
    throw new Error(
      "Use a title up to 120 characters, caption up to 1,000 and location up to 120.",
    );
  return { id, title, body, location };
}
export function pagination(value: string | undefined) {
  const n = Number(value ?? 0);
  return Number.isSafeInteger(n) && n >= 0 && n <= 10000 ? n : 0;
}

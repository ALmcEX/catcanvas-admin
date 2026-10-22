import { uuid } from "./validation";
export function parseRecord(input: Record<string, unknown>) {
  const text = (key: string) =>
    typeof input[key] === "string" ? (input[key] as string).trim() : "";
  const id = text("id") ? uuid(text("id")) : null;
  const kind = text("kind");
  if (!["image", "caption", "text"].includes(kind))
    throw new Error("Choose an AI image or caption.");
  if (!id && input.attestation !== "on")
    throw new Error(
      "Confirm that this is existing AI-generated content and that its source details are accurate.",
    );
  const title = text("title"),
    prompt = text("prompt"),
    body = text("body"),
    model = text("model"),
    location = text("location");
  const length = (value: string) => Array.from(value).length;
  if (
    !title ||
    length(title) > 120 ||
    !prompt ||
    length(prompt) > 1000 ||
    !model ||
    length(model) > 120 ||
    length(location) > 120
  )
    throw new Error(
      "Provide a title (120 max), prompt (1,000 max), source model (120 max), and optional location (120 max).",
    );
  if (kind === "caption" && (!body || length(body) > 300))
    throw new Error("AI captions must contain 1–300 characters.");
  if (kind === "image" && length(body) > 1000)
    throw new Error("Image descriptions must be at most 1,000 characters.");
  if (kind === "text" && (!body || length(body) > 3000))
    throw new Error("AI text must contain 1–3,000 characters.");
  return {
    id,
    kind: kind as "image" | "caption" | "text",
    title,
    prompt,
    body,
    model,
    location,
    publish: input.publish === "on",
    breed: text("breed") || "orange",
    style: text("style") || "photo",
  };
}

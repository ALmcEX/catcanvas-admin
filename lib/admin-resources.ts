import { uuid } from "./validation";
export type AdminRow = Record<string, unknown> & {
  id: string;
  version?: number;
};
export type Field = {
  key: string;
  label: string;
  required?: boolean;
  max?: number;
  kind?: "textarea" | "select" | "uuid" | "email" | "url";
  options?: string[];
  reference?: string;
};
export type Resource = {
  title: string;
  description: string;
  editable: boolean;
  columns: string[];
  fields: Field[];
};
const field = (
  key: string,
  label: string,
  max = 120,
  required = false,
  kind?: Field["kind"],
): Field => ({ key, label, max, required, kind });
const purpose: Field = {
  key: "purpose",
  label: "Purpose",
  kind: "select",
  options: ["caption_choices", "meme_caption", "cat_image"],
  required: true,
};
const model: Field = {
  key: "model_id",
  label: "Model",
  kind: "uuid",
  reference: "llm-models",
};
export const resources: Record<string, Resource> = {
  "prompt-chains": {
    title: "Prompt chains",
    description:
      "Deployed generation workflows. Each current chain makes one provider call; definitions are maintained with application code.",
    editable: false,
    columns: ["name", "code", "purpose", "implementation_version"],
    fields: [],
  },
  "prompt-chain-steps": {
    title: "Prompt chain steps",
    description:
      "The operations and model references used by each deployed chain.",
    editable: false,
    columns: ["operation", "sequence", "chain_id", "model_id"],
    fields: [],
  },
  "prompt-chain-mix": {
    title: "Prompt chain mix",
    description:
      "Control availability and allocation. Each purpose currently has one deployed variant: enabled weights must total 100%. Disabling the variant pauses that generation path.",
    editable: false,
    columns: ["chain_id", "enabled", "weight", "version"],
    fields: [],
  },
  terms: {
    title: "Terms",
    description:
      "Maintain a glossary of terms, definitions and examples. These entries are not legal terms and are not automatically inserted into generation prompts.",
    editable: true,
    columns: ["term", "definition", "example"],
    fields: [
      field("term", "Term", 120, true),
      field("definition", "Definition", 4000, true, "textarea"),
      field("example", "Example", 2000, false, "textarea"),
    ],
  },
  "generation-examples": {
    title: "AI generation examples",
    description:
      "Curated reference examples, kept separate from observed provider responses. Saving an example does not run AI.",
    editable: true,
    columns: ["input_prompt", "output_text", "purpose", "model_id"],
    fields: [
      field("input_prompt", "Input prompt", 4000, true, "textarea"),
      field(
        "output_text",
        "Expected output / description",
        8000,
        true,
        "textarea",
      ),
      purpose,
      model,
      { key: "media_id", label: "Related media ID", kind: "uuid" },
      field("notes", "Notes", 2000, false, "textarea"),
    ],
  },
  "llm-models": {
    title: "LLM models",
    description:
      "Manage the model catalog. Models referenced by deployed steps retain their provider, identifier and modality. New catalog records do not activate inference.",
    editable: true,
    columns: ["name", "model_id", "modality", "provider_id"],
    fields: [
      field("name", "Display name", 120, true),
      {
        key: "provider_id",
        label: "Provider",
        kind: "uuid",
        reference: "llm-providers",
        required: true,
      },
      field("model_id", "Provider model identifier", 120, true),
      {
        key: "modality",
        label: "Modality",
        kind: "select",
        options: ["text", "image"],
        required: true,
      },
      field("description", "Description", 2000, false, "textarea"),
    ],
  },
  "llm-providers": {
    title: "LLM providers",
    description:
      "Provider descriptions and official websites. Credentials remain in server settings. Referenced providers cannot be deleted or have their slug changed.",
    editable: true,
    columns: ["name", "slug", "website"],
    fields: [
      field("name", "Name", 120, true),
      field("slug", "Stable slug", 80, true),
      field("website", "Official website", 508, false, "url"),
      field("description", "Description", 2000, false, "textarea"),
    ],
  },
  "allowed-signup-domains": {
    title: "Allowed signup domains",
    description:
      "Future signup: allow an exact domain OR a whitelisted email. If both lists are empty, signup is unrestricted. Subdomains are separate entries. Existing accounts retain access.",
    editable: true,
    columns: ["domain", "notes"],
    fields: [
      field("domain", "Exact domain", 253, true),
      field("notes", "Notes", 2000, false, "textarea"),
    ],
  },
  "whitelisted-emails": {
    title: "Whitelisted e-mail addresses",
    description:
      "Future signup: allow an exact email OR an allowed domain. If both lists are empty, signup is unrestricted. Existing accounts retain access; whitelist membership does not grant admin privileges.",
    editable: true,
    columns: ["email", "notes"],
    fields: [
      field("email", "E-mail address", 254, true, "email"),
      field("notes", "Notes", 2000, false, "textarea"),
    ],
  },
  "generation-requests": {
    title: "Generation requests",
    description:
      "Accepted generation attempts recorded after this release, including workflow failures. Historical media has no reconstructed logs. Pending means unfinished or finalization could not be recorded.",
    editable: false,
    columns: [
      "purpose",
      "status",
      "prompt",
      "error_code",
      "duration_ms",
      "created_at",
    ],
    fields: [],
  },
  "llm-responses": {
    title: "LLM responses",
    description:
      "Observed provider outputs and reported usage. Network failures have no invented HTTP status. Reasoning, credentials, image bytes and signed URLs are excluded.",
    editable: false,
    columns: [
      "request_id",
      "http_status",
      "output_text",
      "error_code",
      "input_tokens",
      "output_tokens",
    ],
    fields: [],
  },
};
export function getResource(name: string): Resource | undefined {
  return Object.hasOwn(resources, name) ? resources[name] : undefined;
}
export function version(value: unknown): number {
  if (
    typeof value !== "number" &&
    (typeof value !== "string" || !/^\d+$/.test(value))
  )
    throw new Error("Refresh this record before saving.");
  const n = Number(value);
  if (!Number.isSafeInteger(n) || n < 0)
    throw new Error("Refresh this record before saving.");
  return n;
}
export function normalizeConfiguration(
  resource: string,
  input: Record<string, unknown>,
): Record<string, unknown> {
  const config = getResource(resource);
  if (!config?.editable) throw new Error("This resource is read-only.");
  const allowed = new Set(
    config.fields.map((f) => f.key).concat(["id", "version"]),
  );
  if (Object.keys(input).some((k) => !allowed.has(k)))
    throw new Error("Unknown field.");
  const output: Record<string, unknown> = {};
  if (input.id) {
    output.id = uuid(input.id);
    output.version = version(input.version);
  }
  for (const f of config.fields) {
    let value =
      typeof input[f.key] === "string" ? (input[f.key] as string).trim() : "";
    if (f.key === "domain" || f.key === "email") value = value.toLowerCase();
    if (f.required && !value) throw new Error(`${f.label} is required.`);
    if (f.max && Array.from(value).length > f.max)
      throw new Error(`${f.label} must be at most ${f.max} characters.`);
    if (f.kind === "uuid") {
      output[f.key] = value ? uuid(value) : null;
      continue;
    }
    if (f.options && !f.options.includes(value))
      throw new Error(`Choose a valid ${f.label.toLowerCase()}.`);
    if (
      f.key === "domain" &&
      !/^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,63}$/.test(value)
    )
      throw new Error("Enter an exact domain, such as example.edu.");
    if (f.kind === "email" && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value))
      throw new Error("Enter a valid e-mail address.");
    if (f.kind === "url" && value && !/^https:\/\/[^\s]+$/.test(value))
      throw new Error("Use an HTTPS website address.");
    if (f.key === "slug" && !/^[a-z0-9][a-z0-9-]{0,79}$/.test(value))
      throw new Error(
        "Use lowercase letters, digits and hyphens for the slug.",
      );
    if (
      resource === "llm-models" &&
      f.key === "model_id" &&
      !/^[a-zA-Z0-9][a-zA-Z0-9._/-]{0,119}$/.test(value)
    )
      throw new Error("Enter a valid model identifier.");
    output[f.key] = value;
  }
  return output;
}
export function parseMix(input: Record<string, unknown>) {
  const weight = version(input.weight);
  if (weight > 100) throw new Error("Weight must be between 0 and 100.");
  return {
    id: uuid(input.id),
    version: version(input.version),
    weight,
    enabled: input.enabled === "on",
  };
}

export function relationHref(
  resource: string,
  key: string,
  value: unknown,
): string | null {
  if (
    typeof value !== "string" ||
    (resource === "llm-models" && key === "model_id")
  )
    return null;
  const targets: Record<string, string> = {
    chain_id: "prompt-chains",
    request_id: "generation-requests",
    step_id: "prompt-chain-steps",
    model_id: "llm-models",
    provider_id: "llm-providers",
  };
  const target = targets[key];
  if (!target) return null;
  try {
    return `/${target}/${uuid(value)}`;
  } catch {
    return null;
  }
}

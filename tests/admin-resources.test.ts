import { describe, expect, it } from "vitest";
import {
  resources,
  normalizeConfiguration,
  parseMix,
} from "../lib/admin-resources";
const id = "aa770000-0000-4000-8000-000000000001";
describe("configuration boundaries", () => {
  it("normalizes exact signup domains and emails", () => {
    expect(
      normalizeConfiguration("allowed-signup-domains", {
        domain: " EXAMPLE.COM ",
      }).domain,
    ).toBe("example.com");
    expect(
      normalizeConfiguration("whitelisted-emails", {
        email: " Person@Example.COM ",
      }).email,
    ).toBe("person@example.com");
  });
  it("rejects wildcard domains and invalid mailbox strings", () => {
    expect(() =>
      normalizeConfiguration("allowed-signup-domains", {
        domain: "*.example.com",
      }),
    ).toThrow();
    expect(() =>
      normalizeConfiguration("whitelisted-emails", { email: "a@b@c.com" }),
    ).toThrow();
  });
  it("disallows writes to read-only resources or arbitrary fields", () => {
    expect(() => normalizeConfiguration("generation-requests", {})).toThrow();
    expect(() =>
      normalizeConfiguration("terms", {
        term: "cat",
        definition: "pet",
        is_superadmin: true,
      }),
    ).toThrow();
    expect(resources["prompt-chain-mix"].editable).toBe(false);
  });
  it("requires bounded text and valid foreign keys", () => {
    expect(() =>
      normalizeConfiguration("terms", { term: " ", definition: "meaning" }),
    ).toThrow();
    expect(() =>
      normalizeConfiguration("terms", {
        term: "x",
        definition: "x".repeat(4001),
      }),
    ).toThrow();
    expect(() =>
      normalizeConfiguration("llm-models", {
        name: "Model",
        model_id: "valid",
        modality: "text",
        provider_id: "bad",
      }),
    ).toThrow();
  });
  it("preserves the version and drops no required relation", () => {
    const d = normalizeConfiguration("llm-models", {
      id,
      version: "3",
      name: " A ",
      model_id: "model-id",
      modality: "text",
      provider_id: id,
    });
    expect(d).toMatchObject({
      id,
      version: 3,
      name: "A",
      provider_id: id,
      description: "",
    });
    expect(() =>
      normalizeConfiguration("terms", {
        id,
        version: "-1",
        term: "cat",
        definition: "animal",
      }),
    ).toThrow();
  });
  it("validates mix controls without granting arbitrary columns", () => {
    expect(
      parseMix({ id, version: "0", weight: "100", enabled: "on" }),
    ).toEqual({ id, version: 0, weight: 100, enabled: true });
    expect(() => parseMix({ id, version: "0", weight: "101" })).toThrow();
  });
});

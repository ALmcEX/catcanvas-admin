import { describe, it, expect } from "vitest";
import { isAdmin } from "../lib/access";
import { parseMedia } from "../lib/validation";
const user = {
  id: "10000000-0000-4000-8000-000000000001",
  app_metadata: { provider: "google" },
  identities: [{ provider: "google" }],
};
describe("admin authorization", () => {
  it("fails closed without an authenticated user", () =>
    expect(isAdmin(null, { is_superadmin: true })).toBe(false));
  it("requires an exact true flag", () => {
    for (const value of [false, null, undefined, "true", 1])
      expect(isAdmin(user, { id: user.id, is_superadmin: value })).toBe(false);
  });
  it("requires a matching profile", () =>
    expect(isAdmin(user, { id: "other", is_superadmin: true })).toBe(false));
  it("requires Google identity", () =>
    expect(
      isAdmin(
        {
          ...user,
          app_metadata: { provider: "email" },
          identities: [{ provider: "email" }],
        },
        { id: user.id, is_superadmin: true },
      ),
    ).toBe(false));
  it("accepts Google administrator", () =>
    expect(isAdmin(user, { id: user.id, is_superadmin: true })).toBe(true));
});
describe("media validation", () => {
  const fields = {
    id: user.id,
    title: "A cat",
    body: "Caption",
    location: "NYC",
  };
  it("rejects invalid identifiers", () =>
    expect(() => parseMedia({ ...fields, id: "bad" })).toThrow());
  it("rejects overlong title and empty title", () => {
    for (const title of ["", "x".repeat(121)])
      expect(() => parseMedia({ ...fields, title })).toThrow();
  });
  it("rejects oversized body", () =>
    expect(() => parseMedia({ ...fields, body: "x".repeat(1001) })).toThrow());
  it("trims accepted strings and permits empty image caption", () =>
    expect(parseMedia({ ...fields, title: " Cat ", body: "" })).toEqual({
      ...fields,
      title: "Cat",
      body: "",
    }));
});

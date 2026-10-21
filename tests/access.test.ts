import { describe, it, expect } from "vitest";
import { isAdmin } from "../lib/access";
import { parseMedia, parseMutation } from "../lib/validation";
const user = {
  id: "10000000-0000-4000-8000-000000000001",
  app_metadata: { provider: "google" },
  identities: [{ provider: "google" }],
  authenticationMethods: [{ method: "oauth" }],
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

describe("mutation intent", () => {
  it("deletes legacy long publications without editing the content first", () => {
    expect(
      parseMutation({
        operation: "delete",
        id: user.id,
        title: "Legacy",
        body: "x".repeat(3000),
        confirmation: "DELETE",
      }),
    ).toEqual({
      action: "delete",
      id: user.id,
      title: "",
      body: "",
      location: "",
    });
  });
  it("requires explicit deletion confirmation", () =>
    expect(() =>
      parseMutation({ operation: "delete", id: user.id, confirmation: "" }),
    ).toThrow());
  it("validates editable content for update", () =>
    expect(() =>
      parseMutation({
        operation: "update",
        id: user.id,
        title: "Title",
        body: "x".repeat(1001),
      }),
    ).toThrow());
});

describe("Google login session", () => {
  it("rejects password sessions even for a Google account", () =>
    expect(
      isAdmin(
        { ...user, authenticationMethods: [{ method: "password" }] },
        { id: user.id, is_superadmin: true },
      ),
    ).toBe(false));
  it("rejects accounts linked to another OAuth identity", () =>
    expect(
      isAdmin(
        {
          ...user,
          identities: [{ provider: "google" }, { provider: "github" }],
        },
        { id: user.id, is_superadmin: true },
      ),
    ).toBe(false));
});

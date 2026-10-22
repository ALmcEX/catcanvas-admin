import { describe, it, expect } from "vitest";
import { parseRecord } from "../lib/media-record";
const valid = {
  kind: "caption",
  title: "Imported caption",
  prompt: "Original idea",
  body: "I was told there would be a nap.",
  model: "Source model",
  attestation: "on",
  publish: "on",
  location: "NYC",
};
describe("independent media records", () => {
  it("creates a new record without an existing generation ID", () =>
    expect(parseRecord(valid)).toMatchObject({
      kind: "caption",
      id: null,
      publish: true,
      title: "Imported caption",
    }));
  it("requires source attestation for an import", () =>
    expect(() => parseRecord({ ...valid, attestation: "" })).toThrow());
  it("validates prompt and model metadata", () => {
    expect(() => parseRecord({ ...valid, prompt: "" })).toThrow();
    expect(() => parseRecord({ ...valid, model: "" })).toThrow();
  });
  it("enforces caption constraints", () =>
    expect(() => parseRecord({ ...valid, body: "x".repeat(301) })).toThrow());
  it("permits empty public image captions", () =>
    expect(
      parseRecord({ ...valid, kind: "image", body: "", publish: "" }),
    ).toMatchObject({ body: "", publish: false }));
  it("requires valid IDs when updating", () =>
    expect(() => parseRecord({ ...valid, id: "bad" })).toThrow());
});

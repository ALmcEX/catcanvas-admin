import { describe, it, expect } from "vitest";
import { inspectImage } from "../lib/image-input";
const png = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6FeMAAAAASUVORK5CYII=",
  "base64",
);
describe("media import image validation", () => {
  it("reads valid dimensions without trusting browser metadata", async () =>
    expect(await inspectImage(png, "image/png")).toMatchObject({
      width: 1,
      height: 1,
      mime: "image/png",
      extension: "png",
    }));
  it("rejects a renamed non-image file", async () =>
    expect(
      inspectImage(Buffer.from("not an image"), "image/png"),
    ).rejects.toThrow());
  it("rejects mismatched MIME", async () =>
    expect(inspectImage(png, "image/jpeg")).rejects.toThrow());
  it("rejects SVG uploads", async () =>
    expect(
      inspectImage(Buffer.from("<svg/>"), "image/svg+xml"),
    ).rejects.toThrow());
  it("rejects oversized payloads", async () =>
    expect(
      inspectImage(Buffer.alloc(3 * 1024 * 1024 + 1), "image/png"),
    ).rejects.toThrow());
});

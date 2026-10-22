import sharp from "sharp";
export async function inspectImage(buffer: Buffer, declaredMime: string) {
  if (!buffer.length || buffer.length > 3 * 1024 * 1024)
    throw new Error("Choose an image no larger than 3 MB.");
  const formats: Record<string, { mime: string; extension: string }> = {
    png: { mime: "image/png", extension: "png" },
    jpeg: { mime: "image/jpeg", extension: "jpg" },
    webp: { mime: "image/webp", extension: "webp" },
  };
  let info;
  try {
    info = await sharp(buffer, { limitInputPixels: 25_000_000 }).metadata();
  } catch {
    throw new Error("The file is not a supported, readable image.");
  }
  const format = info.format ? formats[info.format] : undefined;
  if (
    !format ||
    format.mime !== declaredMime ||
    !info.width ||
    !info.height ||
    info.width > 10000 ||
    info.height > 10000 ||
    (info.pages ?? 1) > 1
  )
    throw new Error(
      "Use a single-frame PNG, JPEG or WebP image with matching file type.",
    );
  return { ...format, width: info.width, height: info.height };
}

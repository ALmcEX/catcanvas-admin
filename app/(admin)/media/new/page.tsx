import Link from "next/link";
import { requireAdmin } from "@/lib/auth";
import { PageHeading } from "@/components/ui";
import { MediaRecordForm } from "@/components/media-record-form";
export default async function NewMedia() {
  await requireAdmin();
  return (
    <>
      <PageHeading
        kicker="BRING EXISTING AI WORK INTO THE COLLECTION"
        title="Add AI media"
        description="Create an independent media record from an AI image or caption, with its source details."
      />
      <section className="panel new-media-panel">
        <Link className="text-link" href="/media">
          ← Back to media library
        </Link>
        <MediaRecordForm />
      </section>
    </>
  );
}

import "server-only";
import { adminData } from "./data";
import { getResource, type AdminRow } from "./admin-resources";
import type { ReferenceOptions } from "@/components/configuration-form";
export async function referenceOptions(
  resource: string,
): Promise<ReferenceOptions> {
  const refs = [
    ...new Set(
      getResource(resource)?.fields.flatMap((f) =>
        f.reference ? [f.reference] : [],
      ) ?? [],
    ),
  ];
  const result: ReferenceOptions = {};
  await Promise.all(
    refs.map(async (ref) => {
      const data = await adminData<{ rows: AdminRow[] }>(
        "admin_observability_list",
        { p_resource: ref },
      );
      result[ref] = data.rows.map((r) => ({
        id: r.id,
        label: String(r.name ?? r.model_id ?? r.id),
      }));
    }),
  );
  return result;
}

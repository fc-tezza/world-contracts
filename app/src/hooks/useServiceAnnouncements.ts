import { useSuiClient } from "@mysten/dapp-kit";
import { fromBase64, normalizeSuiAddress } from "@mysten/sui/utils";
import { useQuery } from "@tanstack/react-query";
import { ServiceAnnouncement } from "../bcs/discovery";
import { PACKAGE_ID } from "../constants";
import type { DiscoveredService } from "../lib/types";

export function useServiceAnnouncements() {
  const client = useSuiClient();

  return useQuery<DiscoveredService[]>({
    queryKey: ["serviceAnnouncements", PACKAGE_ID],
    staleTime: 60_000,
    queryFn: async () => {
      const events = await client.queryEvents({
        query: {
          MoveEventType: `${PACKAGE_ID}::discovery::NewServiceAnnounced`,
        },
        limit: 50,
      });

      if (events.data.length === 0) return [];

      const announcementIds = events.data
        .map((e) => {
          const parsed = e.parsedJson as { announcement_id?: string };
          return parsed.announcement_id;
        })
        .filter((id): id is string => !!id);

      if (announcementIds.length === 0) return [];

      const objects = await client.multiGetObjects({
        ids: announcementIds,
        options: { showBcs: true, showType: true },
      });

      const results: DiscoveredService[] = [];
      for (const obj of objects) {
        if (!obj.data?.bcs || !("bcsBytes" in obj.data.bcs)) continue;
        try {
          const parsed = ServiceAnnouncement.parse(
            fromBase64(obj.data.bcs.bcsBytes),
          );
          results.push({
            objectId: obj.data.objectId,
            packageId: normalizeSuiAddress(parsed.packageId),
            name: parsed.name,
            description: parsed.description,
            templateFun: parsed.templateFun,
            requirementType: parsed.requirementType.name,
          });
        } catch {
          // skip
        }
      }

      return results;
    },
  });
}

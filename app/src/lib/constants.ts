import { PACKAGE_ID } from "../constants";

/** Matches on-chain `type_name::with_original_ids<world::request::PTB>()`. */
export function ptbExtNamespace(worldPackageId: string = PACKAGE_ID): string {
  const bare = worldPackageId.replace(/^0x/i, "");
  return `0x${bare}::request::PTB`;
}

/** Published `pas` / `ptb` package (same network as world). */
export const PTB_PACKAGE_ID =
  import.meta.env.VITE_PTB_PACKAGE_ID ??
  "0x3533b60e937759b07a079224c1a4a43db92adbc8dbb8926bae6c4f5cc63aa786";

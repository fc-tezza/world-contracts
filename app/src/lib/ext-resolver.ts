import type { TransactionArgument } from "@mysten/sui/transactions";
import { normalizeStructTag } from "@mysten/sui/utils";
import { ptbExtNamespace } from "./constants";
import type { DecodedArgument, ResolutionContext } from "./types";

export function resolveExtInput(
  arg: DecodedArgument & { kind: "ext" },
  ctx: ResolutionContext,
  worldPackageId: string,
): TransactionArgument {
  const expected = normalizeStructTag(ptbExtNamespace(worldPackageId));
  if (normalizeStructTag(arg.namespace) !== expected) {
    throw new Error(
      `Unknown ext_input namespace: "${normalizeStructTag(arg.namespace)}". Expected "${expected}"`,
    );
  }

  switch (arg.name) {
    case "world:request":
      return ctx.requestArg;
    case "world:entity":
      return ctx.entityArg;
    case "item":
      if (!ctx.resolveItem) throw new Error("No item resolver provided");
      return ctx.resolveItem();
    case "owner_cap":
      if (!ctx.resolveOwnerCap) throw new Error("No owner cap resolver provided");
      return ctx.resolveOwnerCap();
    case "proximity_proof":
      if (!ctx.resolveProximityProof) {
        throw new Error("No proximity proof resolver provided");
      }
      return ctx.resolveProximityProof();
    case "admin_acl":
      if (!ctx.resolveAdminAcl) throw new Error("No admin ACL resolver provided");
      return ctx.resolveAdminAcl();
    case "type_id":
      if (!ctx.resolveTypeId) throw new Error("No type_id resolver provided");
      return ctx.resolveTypeId();
    case "quantity":
      if (!ctx.resolveQuantity) throw new Error("No quantity resolver provided");
      return ctx.resolveQuantity();
    default:
      throw new Error(`Unknown ext_input: "${arg.name}"`);
  }
}

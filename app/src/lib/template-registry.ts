import { ptbExtNamespace } from "./constants";
import type { DecodedArgument, RequirementInput, TemplateStep } from "./types";

function ext(name: string, worldPackageId: string): DecodedArgument {
  return { kind: "ext", namespace: ptbExtNamespace(worldPackageId), name };
}

function step(
  packageId: string,
  moduleName: string,
  functionName: string,
  args: DecodedArgument[],
): TemplateStep {
  return {
    kind: "moveCall",
    packageId,
    moduleName,
    functionName,
    arguments: args,
    typeArguments: [],
  };
}

function stripToModuleType(typeName: string): string {
  const match = typeName.match(/^(?:0x)?[0-9a-fA-F]+::(.*)/i);
  return match ? match[1] : typeName;
}

/** Off-chain fallback when devInspect is unavailable (matches on-chain ptb_template_*). */
export function getTemplateSteps(
  worldPackageId: string,
  requirement: RequirementInput,
): TemplateStep[] {
  const moduleAndType = stripToModuleType(requirement.typeName);
  const e = (name: string) => ext(name, worldPackageId);

  switch (moduleAndType) {
    case "module_inventory::Deposit":
      return [
        step(worldPackageId, "module_inventory", "deposit", [
          e("world:request"),
          e("world:entity"),
          e("item"),
        ]),
      ];
    case "module_inventory::Withdrawal":
      return [
        step(worldPackageId, "module_inventory", "withdraw", [
          e("world:request"),
          e("world:entity"),
          e("type_id"),
          e("quantity"),
        ]),
      ];
    case "module_owner::OwnerAuthorization":
      return [
        step(worldPackageId, "module_owner", "verify_ownership", [
          e("world:request"),
          e("world:entity"),
          e("owner_cap"),
        ]),
      ];
    case "location_service::ProximityToLocation":
      return [
        step(worldPackageId, "location_service", "verify_proximity", [
          e("world:request"),
          e("world:entity"),
          e("proximity_proof"),
        ]),
      ];
    case "system_auth::SystemAuthorization":
      return [
        step(worldPackageId, "system_service", "is_authorized", [
          e("world:request"),
          e("world:entity"),
          e("admin_acl"),
        ]),
      ];
    default:
      return [];
  }
}

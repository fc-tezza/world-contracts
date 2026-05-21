import type { Transaction, TransactionArgument } from "@mysten/sui/transactions";
import { resolveExtInput } from "./ext-resolver";
import { getTemplateSteps } from "./template-registry";
import type {
  DecodedArgument,
  DiscoveredService,
  RequirementInput,
  ResolutionContext,
  TemplateStep,
} from "./types";

function stripToModuleType(typeName: string): string {
  const match = typeName.match(/^(?:0x)?[0-9a-fA-F]+::(.*)/i);
  return match ? match[1] : typeName;
}

function resolveArg(
  arg: DecodedArgument,
  ctx: ResolutionContext,
  worldPackageId: string,
  batchResults: TransactionArgument[],
): TransactionArgument {
  if (arg.kind === "ext") {
    return resolveExtInput(arg, ctx, worldPackageId);
  }
  if (arg.kind === "result") {
    const result = batchResults[arg.index];
    if (!result) {
      throw new Error(`Result(${arg.index}) not available`);
    }
    return result;
  }
  throw new Error(`Unsupported argument kind in template: ${arg.kind}`);
}

function executeStep(
  tx: Transaction,
  step: TemplateStep,
  ctx: ResolutionContext,
  worldPackageId: string,
  batchResults: TransactionArgument[],
): TransactionArgument {
  if (step.kind === "makeMoveVec") {
    return tx.makeMoveVec({
      type: step.typeTag,
      elements: step.elements.map((el) =>
        resolveArg(el, ctx, worldPackageId, batchResults),
      ),
    });
  }

  const resolvedArgs = step.arguments.map((arg) =>
    resolveArg(arg, ctx, worldPackageId, batchResults),
  );

  return tx.moveCall({
    target: `${step.packageId}::${step.moduleName}::${step.functionName}`,
    arguments: resolvedArgs,
  });
}

export function applyRequirementSteps(
  tx: Transaction,
  requirements: RequirementInput[],
  params: {
    worldPackageId: string;
    ctx: ResolutionContext;
    resolvedTemplates?: Record<string, TemplateStep[]>;
  },
): void {
  // Action requirement list is satisfied LIFO (last listed = first in PTB).
  for (const requirement of [...requirements].reverse()) {
    const moduleType = stripToModuleType(requirement.typeName);
    const hardcoded = getTemplateSteps(params.worldPackageId, requirement);
    const steps =
      hardcoded.length > 0
        ? hardcoded
        : (params.resolvedTemplates?.[moduleType] ?? []);

    const batchResults: TransactionArgument[] = [];
    for (const step of steps) {
      batchResults.push(
        executeStep(tx, step, params.ctx, params.worldPackageId, batchResults),
      );
    }
  }
}

/** Map requirement TypeName → discovered service (module name from type prefix). */
export function serviceForRequirement(
  services: DiscoveredService[],
  requirementTypeName: string,
): DiscoveredService | undefined {
  const want = stripToModuleType(requirementTypeName);
  return services.find((s) => stripToModuleType(s.requirementType) === want);
}

/** Move module containing `ptb_template` (may differ from the requirement type's module). */
export function templateModuleForService(service: DiscoveredService): string {
  const requirementModule = stripToModuleType(service.requirementType);
  if (requirementModule === "system_auth::SystemAuthorization") {
    return "system_service";
  }
  return requirementModule.split("::")[0];
}

/** LIFO stack order: last requirement in the action list is satisfied first in the PTB. */
export const INVENTORY_DEPOSIT_REQUIREMENTS: RequirementInput[] = [
  { typeName: "module_owner::OwnerAuthorization", data: [] },
  { typeName: "module_inventory::Deposit", data: [] },
];

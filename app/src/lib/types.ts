import type { TransactionArgument } from "@mysten/sui/transactions";

export type DecodedArgument =
  | { kind: "gas" }
  | { kind: "pure"; value: number[] }
  | { kind: "object"; variant: string; data: unknown }
  | { kind: "result"; index: number }
  | { kind: "nestedResult"; index: number; subIndex: number }
  | { kind: "ext"; namespace: string; name: string }
  | { kind: "objectExt"; extString: string }
  | { kind: "raw"; data: number[] };

export type TemplateStep =
  | {
      kind: "moveCall";
      packageId: string;
      moduleName: string;
      functionName: string;
      arguments: DecodedArgument[];
      typeArguments: string[];
    }
  | {
      kind: "makeMoveVec";
      typeTag: string;
      elements: DecodedArgument[];
    };

export type RequirementInput = {
  typeName: string;
  data: number[];
};

/** Context for resolving `request::PTB` ext_input placeholders. */
export type ResolutionContext = {
  requestArg: TransactionArgument;
  entityArg: TransactionArgument;
  entityId: string;
  resolveItem?: () => TransactionArgument;
  resolveOwnerCap?: () => TransactionArgument;
  resolveProximityProof?: () => TransactionArgument;
  resolveAdminAcl?: () => TransactionArgument;
  resolveTypeId?: () => TransactionArgument;
  resolveQuantity?: () => TransactionArgument;
};

export type DiscoveredService = {
  objectId: string;
  packageId: string;
  name: string;
  description: string;
  templateFun: string;
  requirementType: string;
};

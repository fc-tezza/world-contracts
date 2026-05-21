import { bcs } from "@mysten/sui/bcs";
import { Transaction } from "@mysten/sui/transactions";
import { normalizeSuiAddress } from "@mysten/sui/utils";
import { PTB_PACKAGE_ID } from "./constants";

type ClientLike = {
  getNormalizedMoveFunction(input: {
    package: string;
    module: string;
    function: string;
  }): Promise<{ parameters: unknown[] }>;
  devInspectTransactionBlock(input: {
    sender: string;
    transactionBlock: Transaction;
  }): Promise<{
    effects: { status: { status: string; error?: string } };
    results?: { returnValues?: [number[], string][] }[];
  }>;
};

const WithdrawFrom = bcs.enum("WithdrawFrom", {
  Sender: null,
  Sponsor: null,
});

const PtbObjectArg = bcs.enum("PtbObjectArg", {
  ImmOrOwnedObject: bcs.struct("ImmOrOwnedObject", {
    objectId: bcs.Address,
    sequenceNumber: bcs.u64(),
    digest: bcs.Address,
  }),
  SharedObject: bcs.struct("SharedObject", {
    objectId: bcs.Address,
    initialSharedVersion: bcs.u64(),
    isMutable: bcs.bool(),
  }),
  Receiving: bcs.struct("Receiving", {
    objectId: bcs.Address,
    sequenceNumber: bcs.u64(),
    digest: bcs.Address,
  }),
  Ext: bcs.string(),
});

const PtbCallArg = bcs.enum("PtbCallArg", {
  Pure: bcs.vector(bcs.u8()),
  Object: PtbObjectArg,
  FundsWithdrawal: bcs.struct("FundsWithdrawal", {
    amount: bcs.u64(),
    typeName: bcs.string(),
    withdrawFrom: WithdrawFrom,
  }),
  Ext: bcs.struct("ExtCallArg", {
    namespace: bcs.string(),
    name: bcs.string(),
  }),
});

const PtbArgument = bcs.enum("PtbArgument", {
  GasCoin: null,
  Input: PtbCallArg,
  Result: bcs.u16(),
  NestedResult: bcs.struct("NestedResult", {
    idx: bcs.u16(),
    subIdx: bcs.u16(),
  }),
  Ext: bcs.vector(bcs.u8()),
});

const PtbMoveCall = bcs.struct("PtbMoveCall", {
  packageId: bcs.string(),
  moduleName: bcs.string(),
  function: bcs.string(),
  arguments: bcs.vector(PtbArgument),
  typeArguments: bcs.vector(bcs.string()),
});

const PtbMakeMoveVec = bcs.struct("PtbMakeMoveVec", {
  elementType: bcs.option(bcs.string()),
  elements: bcs.vector(PtbArgument),
});

const PtbCommand = bcs.struct("PtbCommand", {
  tag: bcs.u8(),
  data: bcs.vector(bcs.u8()),
});

const PtbTransaction = bcs.struct("PtbTransaction", {
  commands: bcs.vector(PtbCommand),
});

const COMMAND_TAG_MOVE_CALL = 0;
const COMMAND_TAG_MAKE_MOVE_VEC = 5;

import type { DecodedArgument, TemplateStep } from "./types";

export type TemplateResolverParams = {
  servicePackageId: string;
  moduleName: string;
  templateFun: string;
};

export async function resolveTemplateViaDevInspect(
  client: ClientLike,
  params: TemplateResolverParams,
): Promise<TemplateStep[]> {
  const { servicePackageId, moduleName, templateFun } = params;

  const tx = new Transaction();
  const emptyPtb = tx.moveCall({
    target: `${PTB_PACKAGE_ID}::ptb::new`,
  });

  tx.moveCall({
    target: `${servicePackageId}::${moduleName}::${templateFun}`,
    arguments: [emptyPtb],
  });

  const result = await client.devInspectTransactionBlock({
    sender: "0x0000000000000000000000000000000000000000000000000000000000000000",
    transactionBlock: tx,
  });

  if (result.effects.status.status !== "success") {
    throw new Error(
      `devInspect failed for ${servicePackageId}::${moduleName}::${templateFun}: ${result.effects.status.error}`,
    );
  }

  const returnValues = result.results?.at(-1)?.returnValues;
  if (!returnValues || returnValues.length === 0) {
    throw new Error("No return values from devInspect");
  }

  const [bcsBytes] = returnValues[0];
  const ptbTx = PtbTransaction.parse(new Uint8Array(bcsBytes));
  return decodeCommands(ptbTx.commands);
}

function decodeCommands(
  commands: { tag: number; data: number[] }[],
): TemplateStep[] {
  return commands.flatMap((cmd): TemplateStep[] => {
    const data = new Uint8Array(cmd.data);

    if (cmd.tag === COMMAND_TAG_MOVE_CALL) {
      const mc = PtbMoveCall.parse(data);
      return [
        {
          kind: "moveCall",
          packageId: normalizeSuiAddress(mc.packageId),
          moduleName: mc.moduleName,
          functionName: mc.function,
          arguments: mc.arguments.map(decodeArgument),
          typeArguments: mc.typeArguments,
        },
      ];
    }

    if (cmd.tag === COMMAND_TAG_MAKE_MOVE_VEC) {
      const mv = PtbMakeMoveVec.parse(data);
      return [
        {
          kind: "makeMoveVec",
          typeTag: mv.elementType ?? "",
          elements: mv.elements.map(decodeArgument),
        },
      ];
    }

    return [];
  });
}

function decodeArgument(arg: {
  $kind: string;
  GasCoin?: unknown;
  Input?: unknown;
  Result?: number;
  NestedResult?: { idx: number; subIdx: number };
  Ext?: number[];
}): DecodedArgument {
  if (arg.$kind === "GasCoin") return { kind: "gas" };
  if (arg.$kind === "Result") return { kind: "result", index: arg.Result! };
  if (arg.$kind === "NestedResult") {
    return {
      kind: "nestedResult",
      index: arg.NestedResult!.idx,
      subIndex: arg.NestedResult!.subIdx,
    };
  }
  if (arg.$kind === "Input") {
    return decodeCallArg(arg.Input as CallArgParsed);
  }
  return { kind: "raw", data: arg.Ext ?? [] };
}

type CallArgParsed = {
  $kind: string;
  Pure?: number[];
  Object?: ObjectArgParsed;
  Ext?: { namespace: string; name: string };
};

type ObjectArgParsed = {
  $kind: string;
  Ext?: string;
  SharedObject?: { objectId: string };
  ImmOrOwnedObject?: { objectId: string };
};

function decodeCallArg(callArg: CallArgParsed): DecodedArgument {
  if (callArg.$kind === "Pure") {
    return { kind: "pure", value: callArg.Pure ?? [] };
  }
  if (callArg.$kind === "Ext") {
    return {
      kind: "ext",
      namespace: callArg.Ext!.namespace,
      name: callArg.Ext!.name,
    };
  }
  if (callArg.$kind === "Object") {
    const objArg = callArg.Object!;
    if (objArg.$kind === "Ext") {
      return { kind: "objectExt", extString: objArg.Ext! };
    }
    return { kind: "object", variant: objArg.$kind, data: objArg };
  }
  return { kind: "raw", data: [] };
}

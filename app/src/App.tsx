import { ConnectButton, useCurrentAccount, useSignAndExecuteTransaction, useSuiClient } from "@mysten/dapp-kit";
import { Transaction } from "@mysten/sui/transactions";
import { useCallback, useState } from "react";
import { PACKAGE_ID } from "./constants";
import { useServiceAnnouncements } from "./hooks/useServiceAnnouncements";
import {
  applyRequirementSteps,
  INVENTORY_DEPOSIT_REQUIREMENTS,
  serviceForRequirement,
  templateModuleForService,
} from "./lib/entity-transaction-builder";
import { resolveTemplateViaDevInspect } from "./lib/template-resolver";
import type { DiscoveredService, TemplateStep } from "./lib/types";

export default function App() {
  const account = useCurrentAccount();
  const client = useSuiClient();
  const { mutateAsync: signAndExecute } = useSignAndExecuteTransaction();
  const { data: services = [], isLoading: servicesLoading } = useServiceAnnouncements();

  const [entityId, setEntityId] = useState("");
  const [itemId, setItemId] = useState("");
  const [ownerCapId, setOwnerCapId] = useState("");
  const [status, setStatus] = useState("");
  const [mode, setMode] = useState<"manual" | "discover">("discover");

  const buildDepositTx = useCallback(
    async (useDevInspect: boolean) => {
      const tx = new Transaction();
      const entity = tx.object(entityId);
      const request = tx.moveCall({
        target: `${PACKAGE_ID}::entity::interact`,
        arguments: [entity, tx.pure.string("inventory:deposit")],
      });

      const ctx = {
        requestArg: request,
        entityArg: entity,
        entityId,
        resolveItem: () => tx.object(itemId),
        resolveOwnerCap: () => tx.object(ownerCapId),
      };

      let resolvedTemplates: Record<string, TemplateStep[]> | undefined;

      if (useDevInspect) {
        resolvedTemplates = {};
        for (const req of INVENTORY_DEPOSIT_REQUIREMENTS) {
          const svc = serviceForRequirement(services, req.typeName);
          if (!svc) continue;
          const moduleType = req.typeName;
          try {
            const steps = await resolveTemplateViaDevInspect(client, {
              servicePackageId: svc.packageId,
              moduleName: templateModuleForService(svc),
              templateFun: svc.templateFun,
            });
            resolvedTemplates[moduleType] = steps;
          } catch (e) {
            console.warn("devInspect failed for", moduleType, e);
          }
        }
      }

      applyRequirementSteps(tx, INVENTORY_DEPOSIT_REQUIREMENTS, {
        worldPackageId: PACKAGE_ID,
        ctx,
        resolvedTemplates,
      });

      tx.moveCall({
        target: `${PACKAGE_ID}::entity::complete`,
        arguments: [request, entity],
      });

      return tx;
    },
    [client, entityId, itemId, ownerCapId, services],
  );

  async function runDeposit() {
    if (!entityId || !itemId || !ownerCapId) {
      setStatus("Set entity, item, and owner cap object IDs.");
      return;
    }
    try {
      const tx = await buildDepositTx(mode === "discover");
      const result = await signAndExecute({ transaction: tx });
      setStatus(`Submitted (${mode}): ${result.digest}`);
    } catch (e) {
      setStatus(e instanceof Error ? e.message : String(e));
    }
  }

  async function previewTemplates() {
    if (services.length === 0) {
      setStatus("No services discovered. Publish world and refresh.");
      return;
    }
    const lines: string[] = [];
    for (const req of INVENTORY_DEPOSIT_REQUIREMENTS) {
      const svc = serviceForRequirement(services, req.typeName);
      if (!svc) {
        lines.push(`${req.typeName}: no announcement`);
        continue;
      }
      try {
        const steps = await resolveTemplateViaDevInspect(client, {
          servicePackageId: svc.packageId,
          moduleName: templateModuleForService(svc),
          templateFun: svc.templateFun,
        });
        lines.push(
          `${svc.name} (${svc.templateFun}): ${steps.map((s) => (s.kind === "moveCall" ? `${s.moduleName}::${s.functionName}` : s.kind)).join(" → ")}`,
        );
      } catch (e) {
        lines.push(`${svc.name}: devInspect failed — ${e instanceof Error ? e.message : e}`);
      }
    }
    setStatus(lines.join("\n"));
  }

  return (
    <div style={{ fontFamily: "system-ui", padding: 24, maxWidth: 640 }}>
      <h1>Entity Accum POC</h1>
      <p>
        Package: <code>{PACKAGE_ID}</code>
      </p>
      <ConnectButton />

      <section style={{ marginTop: 16 }}>
        <h2>Discovered services</h2>
        {servicesLoading && <p>Loading announcements…</p>}
        {!servicesLoading && services.length === 0 && (
          <p>
            No <code>NewServiceAnnounced</code> events yet. Run <code>pnpm publish:local</code> after{" "}
            <code>sui start</code>.
          </p>
        )}
        <ul style={{ fontSize: 14 }}>
          {services.map((s: DiscoveredService) => (
            <li key={s.objectId}>
              <strong>{s.name}</strong> — <code>{s.requirementType}</code> via{" "}
              <code>
                {s.packageId.slice(0, 10)}…::{s.templateFun}
              </code>
            </li>
          ))}
        </ul>
        <button type="button" onClick={previewTemplates} disabled={!account || services.length === 0}>
          Preview deposit templates (devInspect)
        </button>
      </section>

      <section style={{ marginTop: 16 }}>
        <h2>inventory:deposit</h2>
        <label>
          Build mode{" "}
          <select value={mode} onChange={(e) => setMode(e.target.value as "manual" | "discover")}>
            <option value="discover">Discovery + devInspect (fallback registry)</option>
            <option value="manual">Hardcoded moveCalls only</option>
          </select>
        </label>
        <label>
          Entity ID
          <input value={entityId} onChange={(e) => setEntityId(e.target.value)} style={{ width: "100%" }} />
        </label>
        <label>
          Item ID
          <input value={itemId} onChange={(e) => setItemId(e.target.value)} style={{ width: "100%" }} />
        </label>
        <label>
          OwnerCap ID
          <input value={ownerCapId} onChange={(e) => setOwnerCapId(e.target.value)} style={{ width: "100%" }} />
        </label>
        <button type="button" onClick={runDeposit} disabled={!account} style={{ marginTop: 12 }}>
          Run deposit PTB
        </button>
      </section>

      {status && (
        <pre style={{ marginTop: 16, whiteSpace: "pre-wrap", fontSize: 13 }}>{status}</pre>
      )}
    </div>
  );
}

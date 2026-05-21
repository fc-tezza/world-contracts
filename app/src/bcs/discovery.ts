import { bcs } from "@mysten/sui/bcs";

const TypeName = bcs.struct("TypeName", {
  name: bcs.string(),
});

export const ServiceAnnouncement = bcs.struct("ServiceAnnouncement", {
  id: bcs.Address,
  packageId: bcs.Address,
  name: bcs.string(),
  description: bcs.string(),
  templateFun: bcs.string(),
  requirementType: TypeName,
});

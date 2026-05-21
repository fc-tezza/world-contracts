/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_ENTITY_ACCUM_PACKAGE_ID?: string;
  readonly VITE_SUI_RPC_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

/// Tribe module stub — affiliation id in inner (future gameplay).
///
/// - **Inner:** `tribe_id` per named instance (supports multiple affiliation modules on one entity).
/// - **`expose`:** versioned install gate only; tribe actions (assignments, shared resources) TBD.
/// - Intended for characters; same `install` / `expose` / `attach` pattern as other `module_*` packages.
module world::module_tribe;

use std::string::String;
use world::{entity, module_attach, request};

public struct TribeModule has store {
    tribe_id: u64,
}

const ACTION_VERSION: u64 = 1;

#[error(code = 0)]
const EUnsupportedActionVersion: vector<u8> = b"Unsupported tribe action version";
#[error(code = 1)]
const EModuleNotInstalled: vector<u8> = b"Tribe module instance not installed";

public fun action_version(): u64 {
    ACTION_VERSION
}

public fun install(
    entity: &mut entity::Entity,
    instance: String,
    tribe_id: u64,
    _ctx: &mut TxContext,
): request::Request {
    entity::install(entity, instance, TribeModule { tribe_id }, _ctx);
    module_attach::attach_core_setup(entity)
}

/// Stub: tribe affiliation actions will register here later.
public fun expose(entity: &mut entity::Entity, instance: String, version: u64) {
    assert!(version == ACTION_VERSION, EUnsupportedActionVersion);
    assert!(entity::has_module(entity, instance), EModuleNotInstalled);
}

public fun attach(
    entity: &mut entity::Entity,
    instance: String,
    tribe_id: u64,
    ctx: &mut TxContext,
): request::Request {
    let req = install(entity, instance, tribe_id, ctx);
    expose(entity, instance, ACTION_VERSION);
    req
}

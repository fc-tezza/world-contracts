/// Flags module — connection bitmask on entity UID (no interact actions yet).
///
/// - **Inner:** empty `FlagsModule` (install marker only).
/// - **Accumulator:** `Flags` on entity UID via `mark_connected` / `is_connected`.
/// - **Role:** other modules (e.g. energy, inventory attach) set bits when they attach so
///   systems can query “is energy connected?” without scanning the Bag.
/// - **`expose`:** versioned install gate only; no actions registered until gameplay needs them.
module world::module_flags;

use std::string::String;
use world::{entity, entity_accumulator, module_, module_attach, request};

public struct FlagsModule has store {}

const ACTION_VERSION: u64 = 1;
const ENERGY_BIT: u8 = 2;

#[error(code = 0)]
const EUnsupportedActionVersion: vector<u8> = b"Unsupported flags action version";
#[error(code = 1)]
const EModuleNotInstalled: vector<u8> = b"Flags module instance not installed";

public fun action_version(): u64 {
    ACTION_VERSION
}

public fun module_name(): String {
    b"flags".to_string()
}

public fun install(entity: &mut entity::Entity, instance: String, _ctx: &mut TxContext): request::Request {
    entity::install(entity, instance, FlagsModule {}, _ctx);
    module_attach::attach_core_setup(entity)
}

/// No interact actions yet; validates install + version before other modules rely on flags.
public fun expose(entity: &mut entity::Entity, instance: String, version: u64) {
    assert!(version == ACTION_VERSION, EUnsupportedActionVersion);
    assert!(entity::has_module(entity, instance), EModuleNotInstalled);
}

public fun attach(entity: &mut entity::Entity, ctx: &mut TxContext): request::Request {
    let instance = module_name();
    let req = install(entity, instance, ctx);
    expose(entity, instance, ACTION_VERSION);
    req
}

public(package) fun mark_connected(entity: &mut entity::Entity, bit: u8) {
    entity_accumulator::connect_bit(entity.id_mut(), bit);
}

public(package) fun is_connected(entity: &entity::Entity, bit: u8): bool {
    entity_accumulator::has_bit(entity.id(), bit)
}

public fun energy_bit(): u8 { ENERGY_BIT }

#[test_only]
public fun destroy_installed(entity: &mut entity::Entity, name: String) {
    let FlagsModule {} = module_::take_inner(entity::remove_module_for_testing(entity, name));
}

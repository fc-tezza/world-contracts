/// Example customization module — attach requirements come from `ModuleRegistry` policy.
module world::module_warp;

use std::string::String;
use world::{
    entity,
    item,
    module_,
    module_attach,
    module_registry::ModuleRegistry,
    request,
};

public struct WarpModule has store {
    boost: u64,
}

const ACTION_VERSION: u64 = 1;

#[error(code = 0)]
const EUnsupportedActionVersion: vector<u8> = b"Unsupported warp action version";
#[error(code = 1)]
const EModuleNotInstalled: vector<u8> = b"Warp module instance not installed";

public fun warp_drive_type_id(): u64 {
    item::warp_drive_type_id()
}

public fun module_name(): String {
    b"warp".to_string()
}

public fun install(
    entity: &mut entity::Entity,
    instance: String,
    boost: u64,
    registry: &ModuleRegistry,
    _ctx: &mut TxContext,
): request::Request {
    entity::install(entity, instance, WarpModule { boost }, _ctx);
    module_attach::attach_custom_setup<WarpModule>(entity, registry)
}

public fun expose(entity: &mut entity::Entity, instance: String, version: u64) {
    assert!(version == ACTION_VERSION, EUnsupportedActionVersion);
    assert!(entity::has_module(entity, instance), EModuleNotInstalled);
}

public fun attach(
    entity: &mut entity::Entity,
    boost: u64,
    registry: &ModuleRegistry,
    ctx: &mut TxContext,
): request::Request {
    let instance = module_name();
    let req = install(entity, instance, boost, registry, ctx);
    expose(entity, instance, ACTION_VERSION);
    req
}

#[test_only]
public fun destroy_installed(entity: &mut entity::Entity, name: String) {
    let WarpModule { boost: _ } =
        module_::take_inner(entity::remove_module_for_testing(entity, name));
}

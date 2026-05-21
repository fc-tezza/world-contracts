/// Minimal third-party-shaped module for custom-attach policy tests (no gameplay actions).
module world::module_custom_fixture;

use std::string::String;
use world::{
    entity,
    module_,
    module_attach,
    module_registry::ModuleRegistry,
    request,
};

public struct CustomFixtureModule has store {
    tag: u64,
}

const ACTION_VERSION: u64 = 1;

#[error(code = 0)]
const EUnsupportedActionVersion: vector<u8> = b"Unsupported custom fixture action version";
#[error(code = 1)]
const EModuleNotInstalled: vector<u8> = b"Custom fixture module instance not installed";

public fun module_name(): String {
    b"custom_fixture".to_string()
}

public fun install(
    entity: &mut entity::Entity,
    instance: String,
    tag: u64,
    registry: &ModuleRegistry,
    _ctx: &mut TxContext,
): request::Request {
    entity::install(entity, instance, CustomFixtureModule { tag }, _ctx);
    module_attach::attach_custom_setup<CustomFixtureModule>(entity, registry)
}

public fun expose(entity: &mut entity::Entity, instance: String, version: u64) {
    assert!(version == ACTION_VERSION, EUnsupportedActionVersion);
    assert!(entity::has_module(entity, instance), EModuleNotInstalled);
}

public fun attach(
    entity: &mut entity::Entity,
    tag: u64,
    registry: &ModuleRegistry,
    ctx: &mut TxContext,
): request::Request {
    let instance = module_name();
    let req = install(entity, instance, tag, registry, ctx);
    expose(entity, instance, ACTION_VERSION);
    req
}

#[test_only]
public fun destroy_installed(entity: &mut entity::Entity, name: String) {
    let CustomFixtureModule { tag: _ } =
        module_::take_inner(entity::remove_module_for_testing(entity, name));
}

/// Admin module stub — attach marker for future admin-only actions.
///
/// - **Inner:** empty `AdminModule`.
/// - **Gating today:** entity create/attach setup uses `system_auth` / `system_service`, not this module.
/// - **`expose`:** versioned install gate only; admin interact actions to be added later.
module world::module_admin;

use std::string::String;
use world::{entity, module_, module_attach, request};

public struct AdminModule has store {}

const ACTION_VERSION: u64 = 1;

#[error(code = 0)]
const EUnsupportedActionVersion: vector<u8> = b"Unsupported admin action version";
#[error(code = 1)]
const EModuleNotInstalled: vector<u8> = b"Admin module instance not installed";

public fun action_version(): u64 {
    ACTION_VERSION
}

public fun module_name(): String {
    b"admin".to_string()
}

public fun install(entity: &mut entity::Entity, instance: String, _ctx: &mut TxContext): request::Request {
    entity::install(entity, instance, AdminModule {}, _ctx);
    module_attach::attach_core_setup(entity)
}

/// Stub: actions will register here when admin flows are defined.
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

#[test_only]
public fun destroy_installed(entity: &mut entity::Entity, name: String) {
    let AdminModule {} = module_::take_inner(entity::remove_module_for_testing(entity, name));
}

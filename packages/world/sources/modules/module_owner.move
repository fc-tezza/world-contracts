/// Owner module — `OwnerCap` gating and custom action requirements.
///
/// - **Inner:** empty `OwnerModule` (presence marks that owner flows are installed).
/// - **Requirement:** `OwnerAuthorization` (`on_entity`) — satisfied by `verify_ownership` with `OwnerCap`.
/// - **Actions:** `owner:transfer_cap`; other modules stack `module_owner::requirement()` on their actions.
/// - **Discovery:** announces `OwnerAuthorization` for PTB template resolution.
///
/// `add_custom_requirement` lets the holder extend an existing action’s requirement list
/// (cross-module composition without re-exposing the base action).
module world::module_owner;

use std::{string::String, type_name};
use ptb::ptb;
use world::{
    action,
    discovery,
    entity,
    module_,
    core_module_auth,
    owner_cap::{Self, OwnerCap},
    request,
    requirement::{Self, Requirement},
};

public struct OwnerModule has store {}

public fun module_name(): String {
    b"owner".to_string()
}

public struct OwnerAuthorization has drop {}

const ACTION_VERSION: u64 = 1;

#[error(code = 0)]
const EUnsupportedActionVersion: vector<u8> = b"Unsupported owner action version";
#[error(code = 1)]
const EModuleNotInstalled: vector<u8> = b"Owner module instance not installed";

public fun action_version(): u64 {
    ACTION_VERSION
}

public fun requirement(): Requirement {
    requirement::on_entity<OwnerAuthorization>(vector[])
}

public fun install(entity: &mut entity::Entity, instance: String, _ctx: &mut TxContext): request::Request {
    entity::install(entity, instance, OwnerModule {}, _ctx);
    request::new_setup(
        object::id(entity),
        vector[requirement(), core_module_auth::core_requirement()],
    )
}

public fun expose(entity: &mut entity::Entity, instance: String, version: u64) {
    assert!(version == ACTION_VERSION, EUnsupportedActionVersion);
    assert!(entity::has_module(entity, instance), EModuleNotInstalled);
    entity::expose(
        entity,
        b"owner:transfer_cap".to_string(),
        action::new_versioned(version, vector[requirement()]),
    );
}

public fun attach(entity: &mut entity::Entity, ctx: &mut TxContext): request::Request {
    let instance = module_name();
    let req = install(entity, instance, ctx);
    expose(entity, instance, ACTION_VERSION);
    req
}

public fun verify_ownership(req: &mut request::Request, entity: &entity::Entity, cap: &OwnerCap) {
    assert!(cap.entity_id_of() == object::id(entity), 0);
    let (_, frame) = request::satisfy_on_entity<OwnerAuthorization>(
        req,
        object::id(entity),
        internal::permit(),
    );
    request::enqueue(req, frame);
}

public fun add_custom_requirement(
    entity: &mut entity::Entity,
    cap: &OwnerCap,
    action_name: String,
    custom: Requirement,
) {
    assert!(cap.entity_id_of() == object::id(entity));
    let action_entry = entity::actions_mut(entity).get_mut(&action_name);
    action::add_requirement(action_entry, custom);
}

public fun transfer_cap(_entity: &entity::Entity, cap: OwnerCap, recipient: address) {
    owner_cap::transfer_to(cap, recipient);
}

#[test_only]
public fun destroy_installed(entity: &mut entity::Entity, name: String) {
    let OwnerModule {} = module_::take_inner(entity::remove_module_for_testing(entity, name));
}

#[allow(unused_function)]
fun ptb_template(mut ptb: ptb::Transaction): ptb::Transaction {
    ptb.command(ptb::move_call(
        type_name::defining_id<OwnerAuthorization>().to_string(),
        b"module_owner".to_string(),
        b"verify_ownership".to_string(),
        vector[
            world::request::request(),
            world::request::entity(),
            ptb::ext_input<request::PTB>(b"owner_cap".to_string()),
        ],
        vector[],
    ));
    ptb
}

fun init(ctx: &mut TxContext) {
    discovery::announce_service(
        internal::permit<OwnerAuthorization>(),
        b"Owner Authorization".to_string(),
        b"Requires the entity OwnerCap".to_string(),
        b"ptb_template".to_string(),
        ctx,
    )
}

public fun verify_ownership_template(
    ptb: &mut ptb::Transaction,
    _args: vector<ptb::Argument>,
): vector<ptb::Argument> {
    let package_id = type_name::defining_id<OwnerAuthorization>().to_string();
    ptb.command(ptb::move_call(
        package_id,
        b"module_owner".to_string(),
        b"verify_ownership".to_string(),
        vector[
            world::request::request(),
            world::request::entity(),
            ptb::ext_input<request::PTB>(b"owner_cap".to_string()),
        ],
        vector[],
    ));
    vector[]
}

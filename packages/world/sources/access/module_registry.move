/// World policy for which modules may attach to entities.
///
/// - **Core modules:** admin registers inner types on the core allowlist; attach setup is
///   `OwnerAuthorization` + `core_module_auth::CoreModuleAllowed`.
/// - **Custom modules:** admin registers a **requirement stack** per module inner type; attach setup
///   is owner + those requirements (item consumption, proximity, caps, …) using the same
///   `Requirement` / service pattern as gameplay actions.
module world::module_registry;

use std::type_name::{Self, TypeName};
use sui::table::{Self, Table};
use world::{
    admin_acl::AdminACL,
    core_module_auth,
    request::{Self, Request},
    requirement::Requirement,
};

public struct ModuleRegistry has key {
    id: UID,
    core_modules: Table<TypeName, bool>,
    custom_attach: Table<TypeName, CustomAttachPolicy>,
}

public struct CustomAttachPolicy has store, drop {
    requirements: vector<Requirement>,
}

#[error(code = 0)]
const ENotAuthorized: vector<u8> = b"Not authorized";
#[error(code = 1)]
const EModuleNotAllowed: vector<u8> = b"Module type not on core allowlist";
#[error(code = 2)]
const ECustomModuleNotRegistered: vector<u8> = b"Custom module has no attach policy";
#[error(code = 3)]
const EModuleAlreadyCore: vector<u8> = b"Core modules use the core allowlist, not custom attach policy";

public fun add_core_module<M: store>(
    registry: &mut ModuleRegistry,
    admin_acl: &AdminACL,
    ctx: &TxContext,
) {
    assert!(admin_acl.is_authorized_address(ctx.sender()), ENotAuthorized);
    let tn = type_name::with_original_ids<M>();
    if (!registry.core_modules.contains(tn)) {
        registry.core_modules.add(tn, true);
    };
}

/// Admin configures which requirements must be satisfied to attach a custom module type.
public fun set_custom_attach_policy<M: store>(
    registry: &mut ModuleRegistry,
    admin_acl: &AdminACL,
    requirements: vector<Requirement>,
    ctx: &TxContext,
) {
    assert!(admin_acl.is_authorized_address(ctx.sender()), ENotAuthorized);
    let tn = type_name::with_original_ids<M>();
    assert!(!registry.core_modules.contains(tn), EModuleAlreadyCore);
    let policy = CustomAttachPolicy { requirements };
    if (registry.custom_attach.contains(tn)) {
        let existing = registry.custom_attach.borrow_mut(tn);
        *existing = policy;
    } else {
        registry.custom_attach.add(tn, policy);
    };
}

public fun custom_attach_requirements<M: store>(registry: &ModuleRegistry): &vector<Requirement> {
    let tn = type_name::with_original_ids<M>();
    assert!(registry.custom_attach.contains(tn), ECustomModuleNotRegistered);
    &registry.custom_attach.borrow(tn).requirements
}

public fun assert_core_module_allowed<M: store>(registry: &ModuleRegistry) {
    let tn = type_name::with_original_ids<M>();
    assert!(registry.core_modules.contains(tn), EModuleNotAllowed);
}

public fun is_custom_module_registered<M: store>(registry: &ModuleRegistry): bool {
    registry.custom_attach.contains(type_name::with_original_ids<M>())
}

/// Satisfy `CoreModuleAllowed` after `assert_core_module_allowed`.
public fun satisfy_core_module<M: store>(
    req: &mut Request,
    registry: &ModuleRegistry,
): request::Frame {
    assert_core_module_allowed<M>(registry);
    let entity_id = req.entity_id();
    let (_, frame) = core_module_auth::satisfy(req, entity_id);
    frame
}

fun init(ctx: &mut TxContext) {
    let registry = ModuleRegistry {
        id: object::new(ctx),
        core_modules: table::new(ctx),
        custom_attach: table::new(ctx),
    };
    transfer::share_object(registry);
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext): ModuleRegistry {
    let registry = ModuleRegistry {
        id: object::new(ctx),
        core_modules: table::new(ctx),
        custom_attach: table::new(ctx),
    };
    registry
}

#[test_only]
public fun destroy_for_testing(registry: ModuleRegistry) {
    let ModuleRegistry { id, core_modules, custom_attach } = registry;
    core_modules.drop();
    custom_attach.drop();
    id.delete();
}

#[test_only]
public fun set_custom_attach_policy_for_testing<M: store>(
    registry: &mut ModuleRegistry,
    requirements: vector<Requirement>,
) {
    let tn = type_name::with_original_ids<M>();
    let policy = CustomAttachPolicy { requirements };
    if (registry.custom_attach.contains(tn)) {
        let existing = registry.custom_attach.borrow_mut(tn);
        *existing = policy;
    } else {
        registry.custom_attach.add(tn, policy);
    };
}

#[test_only]
public fun add_core_module_for_testing<M: store>(registry: &mut ModuleRegistry) {
    let tn = type_name::with_original_ids<M>();
    if (!registry.core_modules.contains(tn)) {
        registry.core_modules.add(tn, true);
    };
}

#[test_only]
module world::entity_test_utils;

use std::string::String;
use world::{
    admin_acl::{Self, AdminACL},
    entity,
    entity_test_support,
    item,
    module_admin,
    module_admin::AdminModule,
    module_beacon,
    module_beacon::BeaconModule,
    module_energy,
    module_energy::EnergyModule,
    module_flags,
    module_flags::FlagsModule,
    module_inventory,
    module_inventory::InventoryModule,
    module_metadata,
    module_metadata::MetadataModule,
    module_owner,
    module_owner::OwnerModule,
    module_tribe::TribeModule,
    module_registry::{Self, ModuleRegistry},
    module_warp,
    module_attach,
    install_item_service,
    owner_cap::{Self, OwnerCap},
    request,
    system_service,
};

/// Tear down all known module instances before `entity::destroy_for_testing`.
public fun drain_modules(mut e: entity::Entity): entity::Entity {
    let names = vector[
        module_inventory::module_name(),
        module_owner::module_name(),
        module_metadata::module_name(),
        module_beacon::module_name(),
        module_energy::module_name(),
        module_flags::module_name(),
        module_admin::module_name(),
        module_warp::module_name(),
    ];
    let mut i = 0;
    while (i < names.length()) {
        let n = names[i];
        if (entity::has_module(&e, n)) {
            if (n == module_inventory::module_name()) {
                module_inventory::destroy_installed(&mut e, n);
            } else if (n == module_owner::module_name()) {
                module_owner::destroy_installed(&mut e, n);
            } else if (n == module_metadata::module_name()) {
                module_metadata::destroy_installed(&mut e, n);
            } else if (n == module_beacon::module_name()) {
                module_beacon::destroy_installed(&mut e, n);
            } else if (n == module_energy::module_name()) {
                module_energy::destroy_installed(&mut e, n);
            } else if (n == module_flags::module_name()) {
                module_flags::destroy_installed(&mut e, n);
            } else if (n == module_admin::module_name()) {
                module_admin::destroy_installed(&mut e, n);
            } else if (n == module_warp::module_name()) {
                module_warp::destroy_installed(&mut e, n);
            };
        };
        i = i + 1;
    };
    e
}

public fun drop_create_setup(
    req: request::Request,
    e: &entity::Entity,
    admin: &AdminACL,
    ctx: &TxContext,
) {
    let mut r = req;
    system_service::is_authorized(&mut r, e, admin, ctx);
    request::complete_ignore(r);
}

public fun drop_core_attach_setup<M: store>(
    req: request::Request,
    e: &entity::Entity,
    cap: &OwnerCap,
    registry: &ModuleRegistry,
) {
    module_attach::finish_core_attach_for_testing<M>(req, e, cap, registry);
}

fun register_core_modules_for_testing(registry: &mut ModuleRegistry) {
    module_registry::add_core_module_for_testing<InventoryModule>(registry);
    module_registry::add_core_module_for_testing<EnergyModule>(registry);
    module_registry::add_core_module_for_testing<BeaconModule>(registry);
    module_registry::add_core_module_for_testing<MetadataModule>(registry);
    module_registry::add_core_module_for_testing<FlagsModule>(registry);
    module_registry::add_core_module_for_testing<OwnerModule>(registry);
    module_registry::add_core_module_for_testing<AdminModule>(registry);
    module_registry::add_core_module_for_testing<TribeModule>(registry);
}

public fun setup_test_world(ctx: &mut TxContext): (AdminACL, ModuleRegistry) {
    let admin = admin_acl::init_for_testing(ctx);
    let mut registry = module_registry::init_for_testing(ctx);
    register_core_modules_for_testing(&mut registry);
    module_registry::set_custom_attach_policy_for_testing<module_warp::WarpModule>(
        &mut registry,
        vector[install_item_service::requirement(item::warp_drive_type_id())],
    );
    (admin, registry)
}

public fun setup_in_space(ctx: &mut TxContext): (entity::Entity, OwnerCap, ModuleRegistry, AdminACL) {
    let (admin, registry) = setup_test_world(ctx);
    let (e, cap, setup) = entity::create_in_space(ctx);
    drop_create_setup(setup, &e, &admin, ctx);
    (e, cap, registry, admin)
}

public fun attach_inventory(
    e: &mut entity::Entity,
    max_slots: u64,
    max_volume: u64,
    cap: &OwnerCap,
    registry: &ModuleRegistry,
    ctx: &mut TxContext,
) {
    drop_core_attach_setup<world::module_inventory::InventoryModule>(
        module_inventory::attach(e, max_slots, max_volume, ctx),
        e,
        cap,
        registry,
    );
}

public fun teardown(
    e: entity::Entity,
    cap: OwnerCap,
    admin: AdminACL,
    registry: ModuleRegistry,
) {
    entity::destroy_for_testing(e);
    owner_cap::destroy_for_testing(cap);
    teardown_world(admin, registry);
}

public fun teardown_world(admin: AdminACL, registry: ModuleRegistry) {
    admin_acl::destroy_for_testing(admin);
    module_registry::destroy_for_testing(registry);
}

public fun teardown_probe(
    mut e: entity::Entity,
    cap: OwnerCap,
    inst: String,
    admin: AdminACL,
    registry: ModuleRegistry,
) {
    entity_test_support::destroy_probe(&mut e, inst);
    teardown(e, cap, admin, registry);
}

public fun teardown_probes(
    mut e: entity::Entity,
    cap: OwnerCap,
    insts: vector<String>,
    admin: AdminACL,
    registry: ModuleRegistry,
) {
    let mut i = 0;
    while (i < insts.length()) {
        let n = insts[i];
        if (entity::has_module(&e, n)) {
            entity_test_support::destroy_probe(&mut e, n);
        };
        i = i + 1;
    };
    teardown(e, cap, admin, registry);
}

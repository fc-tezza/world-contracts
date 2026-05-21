#[test_only]
module world::entity_tests;

use std::unit_test::assert_eq;
use world::{
    admin_acl,
    entity,
    entity_accumulator,
    entity_test_utils,
    item,
    module_beacon,
    module_energy,
    module_flags,
    module_inventory,
    module_metadata,
    module_owner,
    module_registry,
    module_beacon::BeaconModule,
    module_energy::EnergyModule,
    module_flags::FlagsModule,
    module_inventory::InventoryModule,
    module_metadata::MetadataModule,
    owner_cap,
    request,
};

fun drain_modules(e: entity::Entity): entity::Entity {
    entity_test_utils::drain_modules(e)
}

fun finish_create(req: request::Request, e: &entity::Entity, admin: &admin_acl::AdminACL, ctx: &TxContext) {
    entity_test_utils::drop_create_setup(req, e, admin, ctx);
}

fun finish_core_attach<M: store>(
    req: request::Request,
    e: &entity::Entity,
    cap: &owner_cap::OwnerCap,
    registry: &module_registry::ModuleRegistry,
) {
    entity_test_utils::drop_core_attach_setup<M>(req, e, cap, registry);
}

#[test]
fun in_space_inventory_updates_mass_and_volume() {
    let mut ctx = tx_context::dummy();
    let (mut e, cap, registry, admin) = entity_test_utils::setup_in_space(&mut ctx);

    finish_core_attach<InventoryModule>(
        module_inventory::attach(&mut e, 8, 100, &mut ctx),
        &e,
        &cap,
        &registry,
    );

    let deposit_item = item::new(1, 5, 10, 4, &mut ctx);
    let mut deposit_req = entity::interact(&mut e, b"inventory:deposit".to_string());
    module_inventory::deposit(&mut deposit_req, &mut e, deposit_item);
    assert_eq!(deposit_req.remaining(), 1);
    module_owner::verify_ownership(&mut deposit_req, &e, &cap);
    entity::complete(deposit_req, &mut e);

    assert_eq!(entity_accumulator::mass(e.id()), 50);
    assert_eq!(module_inventory::used_volume(&e), 20);
    assert_eq!(module_inventory::max_volume(&e), 100);
    entity::destroy_for_testing(drain_modules(e));
    owner_cap::destroy_for_testing(cap);
    entity_test_utils::teardown_world(admin, registry);
}

#[test]
#[expected_failure(abort_code = module_inventory::EVolumeExceeded)]
fun deposit_aborts_when_volume_exceeded() {
    let mut ctx = tx_context::dummy();
    let (mut e, cap, registry, admin) = entity_test_utils::setup_in_space(&mut ctx);
    finish_core_attach<InventoryModule>(
        module_inventory::attach(&mut e, 8, 10, &mut ctx),
        &e,
        &cap,
        &registry,
    );

    let deposit_item = item::new(1, 5, 1, 3, &mut ctx);
    let mut deposit_req = entity::interact(&mut e, b"inventory:deposit".to_string());
    module_inventory::deposit(&mut deposit_req, &mut e, deposit_item);
    module_owner::verify_ownership(&mut deposit_req, &e, &cap);
    entity::complete(deposit_req, &mut e);

    entity::destroy_for_testing(drain_modules(e));
    owner_cap::destroy_for_testing(cap);
    entity_test_utils::teardown_world(admin, registry);
}

#[test]
fun publicly_gated_beacon_has_no_owner_req() {
    let mut ctx = tx_context::dummy();
    let (admin, registry) = entity_test_utils::setup_test_world(&mut ctx);
    let (mut e, _cap, setup) = entity::create_in_space(&mut ctx);
    finish_create(setup, &e, &admin, &ctx);

    finish_core_attach<BeaconModule>(
        module_beacon::attach(&mut e, b"sector-7", &mut ctx),
        &e,
        &_cap,
        &registry,
    );

    let mut ping_req = entity::interact(&mut e, b"beacon:ping".to_string());
    module_beacon::ping(&mut ping_req, &e);
    assert_eq!(ping_req.remaining(), 1);
    request::complete_ignore(ping_req);
    entity::destroy_for_testing(drain_modules(e));
    owner_cap::destroy_for_testing(_cap);
    entity_test_utils::teardown_world(admin, registry);
}

#[test]
fun character_metadata_owner_gated() {
    let mut ctx = tx_context::dummy();
    let (admin, registry) = entity_test_utils::setup_test_world(&mut ctx);
    let (mut e, cap, setup) = entity::create_character(&mut ctx);
    finish_create(setup, &e, &admin, &ctx);

    finish_core_attach<MetadataModule>(
        module_metadata::attach(&mut e, b"Pilot".to_string(), &mut ctx),
        &e,
        &cap,
        &registry,
    );

    let mut set_req = entity::interact(&mut e, b"metadata:set_name".to_string());
    module_metadata::set_name(&mut set_req, &mut e, b"Ace".to_string());
    assert_eq!(set_req.remaining(), 1);
    module_owner::verify_ownership(&mut set_req, &e, &cap);
    entity::complete(set_req, &mut e);
    assert_eq!(module_metadata::display_name(&e), b"Ace".to_string());
    entity::destroy_for_testing(drain_modules(e));
    owner_cap::destroy_for_testing(cap);
    entity_test_utils::teardown_world(admin, registry);
}

#[test]
fun composite_action_merges_requirements() {
    let mut ctx = tx_context::dummy();
    let (mut e, cap, registry, admin) = entity_test_utils::setup_in_space(&mut ctx);

    finish_core_attach<BeaconModule>(
        module_beacon::attach(&mut e, b"base", &mut ctx),
        &e,
        &cap,
        &registry,
    );
    finish_core_attach<InventoryModule>(
        module_inventory::attach(&mut e, 4, 1000, &mut ctx),
        &e,
        &cap,
        &registry,
    );

    entity::expose_composite(
        &mut e,
        b"ops:deposit_at_beacon".to_string(),
        vector[b"inventory:deposit".to_string(), b"beacon:ping".to_string()],
        vector[],
    );

    let req = entity::interact(&mut e, b"ops:deposit_at_beacon".to_string());
    assert_eq!(req.remaining(), 3);
    request::complete_ignore(req);
    entity::destroy_for_testing(drain_modules(e));
    owner_cap::destroy_for_testing(cap);
    entity_test_utils::teardown_world(admin, registry);
}

#[test]
fun install_without_expose_registers_no_actions() {
    let mut ctx = tx_context::dummy();
    let (mut e, cap, registry, admin) = entity_test_utils::setup_in_space(&mut ctx);
    let instance = module_energy::module_name();
    finish_core_attach<EnergyModule>(
        module_energy::install(&mut e, instance, 100, &mut ctx),
        &e,
        &cap,
        &registry,
    );
    assert_eq!(entity::action_count(&e), 0);
    entity::destroy_for_testing(drain_modules(e));
    owner_cap::destroy_for_testing(cap);
    entity_test_utils::teardown_world(admin, registry);
}

#[test]
fun flags_mark_connected_modules() {
    let mut ctx = tx_context::dummy();
    let (mut e, cap, registry, admin) = entity_test_utils::setup_in_space(&mut ctx);

    finish_core_attach<FlagsModule>(module_flags::attach(&mut e, &mut ctx), &e, &cap, &registry);
    finish_core_attach<EnergyModule>(
        module_energy::attach(&mut e, 100, &mut ctx),
        &e,
        &cap,
        &registry,
    );

    assert!(module_flags::is_connected(&e, module_flags::energy_bit()));
    entity::destroy_for_testing(drain_modules(e));
    owner_cap::destroy_for_testing(cap);
    entity_test_utils::teardown_world(admin, registry);
}

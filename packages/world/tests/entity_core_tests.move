#[test_only]
/// Framework / core coverage: entity shell, request flow, bag attachment, accumulators, cross-module.
module world::entity_core_tests;

use std::unit_test::assert_eq;
use world::{
    entity,
    entity_accumulator,
    entity_test_support,
    entity_test_utils,
    item,
    location_service,
    module_beacon,
    module_energy,
    module_flags,
    module_inventory,
    module_owner,
    module_registry,
    module_warp,
    install_item_service,
    module_flags::FlagsModule,
    module_energy::EnergyModule,
    module_beacon::BeaconModule,
    module_owner::OwnerModule,
    module_warp::WarpModule,
    owner_cap,
    request,
};

// ── Entity shell & accumulators ────────────────────────────────────────

#[test]
fun create_in_space_initializes_accumulators() {
    let mut ctx = tx_context::dummy();
    let (admin, _registry) = entity_test_utils::setup_test_world(&mut ctx);
    let (e, _cap, setup) = entity::create_in_space(&mut ctx);
    assert_eq!(entity_accumulator::mass(e.id()), 0);
    assert_eq!(entity_accumulator::energy(e.id()), 0);
    assert_eq!(entity_accumulator::inventory_volume(e.id()), 0);
    assert!(entity::is_in_space(&e));
    assert!(!entity::is_character(&e));
    assert_eq!(setup.remaining(), 1);
    entity_test_utils::drop_create_setup(setup, &e, &admin, &ctx);
    entity::destroy_for_testing(e);
    owner_cap::destroy_for_testing(_cap);
    entity_test_utils::teardown_world(admin, _registry);
}

#[test]
fun create_character_differs_by_kind() {
    let mut ctx = tx_context::dummy();
    let (admin, registry) = entity_test_utils::setup_test_world(&mut ctx);
    let (e, cap, setup) = entity::create_character(&mut ctx);
    assert!(entity::is_character(&e));
    assert!(!entity::is_in_space(&e));
    entity_test_utils::drop_create_setup(setup, &e, &admin, &ctx);
    entity::destroy_for_testing(e);
    owner_cap::destroy_for_testing(cap);
    entity_test_utils::teardown_world(admin, registry);
}

// ── Module bag: install / expose / named instances ─────────────────────

#[test]
fun install_without_expose_registers_no_actions() {
    let mut ctx = tx_context::dummy();
    let (mut e, cap, registry, admin) = entity_test_utils::setup_in_space(&mut ctx);
    entity_test_support::install_probe(&mut e, b"probe".to_string(), 1, &mut ctx);
    assert_eq!(entity::action_count(&e), 0);
    entity_test_support::destroy_probe(&mut e, b"probe".to_string());
    entity::destroy_for_testing(e);
    owner_cap::destroy_for_testing(cap);
    entity_test_utils::teardown_world(admin, registry);
}

#[test]
fun expose_after_install_registers_action() {
    let mut ctx = tx_context::dummy();
    let (mut e, cap, registry, admin) = entity_test_utils::setup_in_space(&mut ctx);
    let inst = b"probe".to_string();
    entity_test_support::install_probe(&mut e, inst, 0, &mut ctx);
    entity_test_support::expose_two_slot_action(&mut e, b"probe:run".to_string(), inst);
    assert_eq!(entity::action_count(&e), 1);
    entity_test_support::destroy_probe(&mut e, inst);
    entity::destroy_for_testing(e);
    owner_cap::destroy_for_testing(cap);
    entity_test_utils::teardown_world(admin, registry);
}

#[test]
#[expected_failure(abort_code = entity::EModuleAlreadyAttached)]
fun duplicate_instance_name_on_install_aborts() {
    let mut ctx = tx_context::dummy();
    let (mut e, cap, registry, admin) = entity_test_utils::setup_in_space(&mut ctx);
    let inst = b"dup".to_string();
    entity_test_support::install_probe(&mut e, inst, 1, &mut ctx);
    entity_test_support::install_probe(&mut e, inst, 2, &mut ctx);
    entity_test_support::destroy_probe(&mut e, inst);
    entity::destroy_for_testing(e);
    owner_cap::destroy_for_testing(cap);
    entity_test_utils::teardown_world(admin, registry);
}

#[test]
fun two_named_instances_same_type_in_bag() {
    let mut ctx = tx_context::dummy();
    let (mut e, cap, registry, admin) = entity_test_utils::setup_in_space(&mut ctx);
    entity_test_support::install_probe(&mut e, b"alpha".to_string(), 10, &mut ctx);
    entity_test_support::install_probe(&mut e, b"beta".to_string(), 20, &mut ctx);
    assert!(entity::has_module(&e, b"alpha".to_string()));
    assert!(entity::has_module(&e, b"beta".to_string()));
    assert_eq!(entity_test_support::probe_value(&e, b"alpha".to_string()), 10);
    assert_eq!(entity_test_support::probe_value(&e, b"beta".to_string()), 20);
    entity_test_support::destroy_probe(&mut e, b"alpha".to_string());
    entity_test_support::destroy_probe(&mut e, b"beta".to_string());
    entity::destroy_for_testing(e);
    owner_cap::destroy_for_testing(cap);
    entity_test_utils::teardown_world(admin, registry);
}

// ── Action / request flow (LIFO, in-flight, complete) ──────────────────

#[test]
fun interact_lifo_satisfies_module_slot_before_entity_gate() {
    let mut ctx = tx_context::dummy();
    let (mut e, cap, registry, admin) = entity_test_utils::setup_in_space(&mut ctx);
    let inst = b"probe".to_string();
    entity_test_support::install_probe(&mut e, inst, 0, &mut ctx);
    entity_test_support::expose_two_slot_action(&mut e, b"probe:run".to_string(), inst);

    let mut req = entity::interact(&mut e, b"probe:run".to_string());
    assert_eq!(req.remaining(), 2);

    entity_test_support::satisfy_slot_a(&mut req, &e, inst);
    assert_eq!(req.remaining(), 1);

    entity_test_support::satisfy_entity_gate(&mut req, &e);
    assert_eq!(req.remaining(), 0);

    entity::complete(req, &mut e);

    let req2 = entity::interact(&mut e, b"probe:run".to_string());
    entity::abandon_interact(req2, &mut e);

    entity_test_support::destroy_probe(&mut e, inst);
    entity::destroy_for_testing(e);
    owner_cap::destroy_for_testing(cap);
    entity_test_utils::teardown_world(admin, registry);
}

#[test]
#[expected_failure(abort_code = request::ERequirementsRemain)]
fun complete_aborts_when_requirements_remain() {
    let mut ctx = tx_context::dummy();
    let (mut e, cap, registry, admin) = entity_test_utils::setup_in_space(&mut ctx);
    let inst = b"probe".to_string();
    entity_test_support::install_probe(&mut e, inst, 0, &mut ctx);
    entity_test_support::expose_two_slot_action(&mut e, b"probe:run".to_string(), inst);

    let req = entity::interact(&mut e, b"probe:run".to_string());
    entity::complete(req, &mut e);
    entity_test_utils::teardown_probe(e, cap, inst, admin, registry);
}

#[test]
fun interact_sets_in_flight_until_complete_or_abandon() {
    let mut ctx = tx_context::dummy();
    let (mut e, cap, registry, admin) = entity_test_utils::setup_in_space(&mut ctx);
    let inst = b"probe".to_string();
    entity_test_support::install_probe(&mut e, inst, 0, &mut ctx);
    entity_test_support::expose_two_slot_action(&mut e, b"probe:run".to_string(), inst);

    let req = entity::interact(&mut e, b"probe:run".to_string());
    assert!(entity::has_interact_in_flight(&e));

    entity::abandon_interact(req, &mut e);
    assert!(!entity::has_interact_in_flight(&e));

    let req2 = entity::interact(&mut e, b"probe:run".to_string());
    entity::abandon_interact(req2, &mut e);

    entity_test_utils::teardown_probe(e, cap, inst, admin, registry);
}

#[test]
#[expected_failure(abort_code = entity::EInteractInFlight)]
fun interact_aborts_when_in_flight_already_set() {
    let mut ctx = tx_context::dummy();
    let (mut e, cap, registry, admin) = entity_test_utils::setup_in_space(&mut ctx);
    entity::mark_inflight_for_testing(&mut e);

    let req = entity::interact(&mut e, b"probe:run".to_string());
    entity::abandon_interact(req, &mut e);
    entity_test_utils::teardown(e, cap, admin, registry);
}

#[test]
#[expected_failure(abort_code = request::EModuleMismatch)]
fun satisfy_aborts_when_module_instance_does_not_match() {
    let mut ctx = tx_context::dummy();
    let (mut e, cap, registry, admin) = entity_test_utils::setup_in_space(&mut ctx);
    entity_test_support::install_probe(&mut e, b"expected".to_string(), 0, &mut ctx);
    entity_test_support::install_probe(&mut e, b"other".to_string(), 0, &mut ctx);
    entity_test_support::expose_two_slot_action(
        &mut e,
        b"probe:run".to_string(),
        b"expected".to_string(),
    );

    let mut req = entity::interact(&mut e, b"probe:run".to_string());
    entity_test_support::satisfy_slot_a(&mut req, &e, b"other".to_string());
    entity::abandon_interact(req, &mut e);
    entity_test_utils::teardown_probes(
        e,
        cap,
        vector[b"expected".to_string(), b"other".to_string()],
        admin,
        registry,
    );
}

#[test]
#[expected_failure(abort_code = request::ERequirementTypeMismatch)]
fun satisfy_aborts_when_requirement_type_wrong() {
    let mut ctx = tx_context::dummy();
    let (mut e, cap, registry, admin) = entity_test_utils::setup_in_space(&mut ctx);
    let inst = b"probe".to_string();
    entity_test_support::install_probe(&mut e, inst, 0, &mut ctx);
    entity_test_support::expose_two_slot_action(&mut e, b"probe:run".to_string(), inst);

    let mut req = entity::interact(&mut e, b"probe:run".to_string());
    entity_test_support::satisfy_slot_b(&mut req, &e, inst);
    entity::abandon_interact(req, &mut e);
    entity_test_utils::teardown_probe(e, cap, inst, admin, registry);
}

// ── Composite actions (cross-action requirements) ──────────────────────

#[test]
fun expose_composite_unions_base_action_requirements() {
    let mut ctx = tx_context::dummy();
    let (mut e, cap, registry, admin) = entity_test_utils::setup_in_space(&mut ctx);
    let inst = b"probe".to_string();
    entity_test_support::install_probe(&mut e, inst, 0, &mut ctx);
    entity_test_support::expose_two_slot_action(&mut e, b"probe:run".to_string(), inst);
    entity_test_support::expose_two_slot_action(&mut e, b"probe:again".to_string(), inst);

    entity::expose_composite(
        &mut e,
        b"combo".to_string(),
        vector[b"probe:run".to_string(), b"probe:again".to_string()],
        vector[],
    );

    let req = entity::interact(&mut e, b"combo".to_string());
    assert_eq!(req.remaining(), 4);
    entity::abandon_interact(req, &mut e);

    entity_test_support::destroy_probe(&mut e, inst);
    entity::destroy_for_testing(e);
    owner_cap::destroy_for_testing(cap);
    entity_test_utils::teardown_world(admin, registry);
}

// ── Cross-module + accumulators (minimal module drivers) ───────────────

#[test]
fun inventory_deposit_updates_entity_accumulators() {
    let mut ctx = tx_context::dummy();
    let (mut e, cap, registry, admin) = entity_test_utils::setup_in_space(&mut ctx);
    entity_test_utils::attach_inventory(&mut e, 4, 100, &cap, &registry, &mut ctx);

    let deposit_item = item::new(1, 2, 10, 5, &mut ctx);
    let mut req = entity::interact(&mut e, b"inventory:deposit".to_string());
    assert_eq!(req.remaining(), 2);
    module_inventory::deposit(&mut req, &mut e, deposit_item);
    assert_eq!(req.remaining(), 1);
    module_owner::verify_ownership(&mut req, &e, &cap);
    entity::complete(req, &mut e);

    assert_eq!(entity_accumulator::mass(e.id()), 20);
    assert_eq!(entity_accumulator::inventory_volume(e.id()), 10);

    entity::destroy_for_testing(entity_test_utils::drain_modules(e));
    owner_cap::destroy_for_testing(cap);
    entity_test_utils::teardown_world(admin, registry);
}

#[test]
fun withdraw_splits_entity_accumulators() {
    let mut ctx = tx_context::dummy();
    let (mut e, cap, registry, admin) = entity_test_utils::setup_in_space(&mut ctx);
    entity_test_utils::attach_inventory(&mut e, 4, 100, &cap, &registry, &mut ctx);

    let mut deposit_req = entity::interact(&mut e, b"inventory:deposit".to_string());
    module_inventory::deposit(&mut deposit_req, &mut e, item::new(7, 4, 5, 2, &mut ctx));
    module_owner::verify_ownership(&mut deposit_req, &e, &cap);
    entity::complete(deposit_req, &mut e);

    let mut withdraw_req = entity::interact(&mut e, b"inventory:withdraw".to_string());
    let withdrawn = module_inventory::withdraw(&mut withdraw_req, &mut e, 7, 2, &mut ctx);
    item::destroy_for_testing(withdrawn);
    module_owner::verify_ownership(&mut withdraw_req, &e, &cap);
    entity::complete(withdraw_req, &mut e);

    assert_eq!(entity_accumulator::mass(e.id()), 10);
    assert_eq!(entity_accumulator::inventory_volume(e.id()), 4);

    entity::destroy_for_testing(entity_test_utils::drain_modules(e));
    owner_cap::destroy_for_testing(cap);
    entity_test_utils::teardown_world(admin, registry);
}

#[test]
fun flags_and_energy_attach_marks_connection_bit() {
    let mut ctx = tx_context::dummy();
    let (mut e, cap, registry, admin) = entity_test_utils::setup_in_space(&mut ctx);

    entity_test_utils::drop_core_attach_setup<FlagsModule>(
        module_flags::attach(&mut e, &mut ctx),
        &e,
        &cap,
        &registry,
    );
    entity_test_utils::drop_core_attach_setup<EnergyModule>(
        module_energy::attach(&mut e, 50, &mut ctx),
        &e,
        &cap,
        &registry,
    );

    assert!(module_flags::is_connected(&e, module_flags::energy_bit()));

    entity::destroy_for_testing(entity_test_utils::drain_modules(e));
    owner_cap::destroy_for_testing(cap);
    entity_test_utils::teardown_world(admin, registry);
}

#[test]
fun owner_can_extend_action_requirements_cross_module() {
    let mut ctx = tx_context::dummy();
    let (mut e, cap, registry, admin) = entity_test_utils::setup_in_space(&mut ctx);
    entity_test_utils::attach_inventory(&mut e, 2, 50, &cap, &registry, &mut ctx);
    entity_test_utils::drop_core_attach_setup<OwnerModule>(
        module_owner::attach(&mut e, &mut ctx),
        &e,
        &cap,
        &registry,
    );

    let extra = location_service::requirement(b"sector");
    module_owner::add_custom_requirement(
        &mut e,
        &cap,
        b"inventory:deposit".to_string(),
        extra,
    );

    let req = entity::interact(&mut e, b"inventory:deposit".to_string());
    assert_eq!(req.remaining(), 3);
    entity::abandon_interact(req, &mut e);

    entity::destroy_for_testing(entity_test_utils::drain_modules(e));
    owner_cap::destroy_for_testing(cap);
    entity_test_utils::teardown_world(admin, registry);
}

#[test]
fun beacon_and_inventory_composite_interact_stack() {
    let mut ctx = tx_context::dummy();
    let (mut e, cap, registry, admin) = entity_test_utils::setup_in_space(&mut ctx);

    entity_test_utils::drop_core_attach_setup<BeaconModule>(
        module_beacon::attach(&mut e, b"base", &mut ctx),
        &e,
        &cap,
        &registry,
    );
    entity_test_utils::attach_inventory(&mut e, 2, 100, &cap, &registry, &mut ctx);

    entity::expose_composite(
        &mut e,
        b"ops:ping_and_deposit".to_string(),
        vector[b"beacon:ping".to_string(), b"inventory:deposit".to_string()],
        vector[],
    );

    // beacon:ping (proximity) + inventory:deposit (owner + deposit) = 3 requirements
    let req = entity::interact(&mut e, b"ops:ping_and_deposit".to_string());
    assert_eq!(req.remaining(), 3);
    entity::abandon_interact(req, &mut e);

    entity::destroy_for_testing(entity_test_utils::drain_modules(e));
    owner_cap::destroy_for_testing(cap);
    entity_test_utils::teardown_world(admin, registry);
}

#[test]
fun admin_destroy_entity_requires_empty_shell() {
    let mut ctx = tx_context::dummy();
    let (admin, registry) = entity_test_utils::setup_test_world(&mut ctx);
    let (e, cap, setup) = entity::create_in_space(&mut ctx);
    entity_test_utils::drop_create_setup(setup, &e, &admin, &ctx);
    owner_cap::destroy_for_testing(cap);
    entity::destroy_entity(e, &admin, &ctx);
    entity_test_utils::teardown_world(admin, registry);
}

#[test]
fun owner_attaches_custom_module_via_admin_requirement_stack() {
    let mut ctx = tx_context::dummy();
    let (mut e, cap, registry, admin) = entity_test_utils::setup_in_space(&mut ctx);
    let drive = item::new(item::warp_drive_type_id(), 1, 0, 0, &mut ctx);
    let mut req = module_warp::attach(&mut e, 2, &registry, &mut ctx);
    assert_eq!(req.remaining(), 2);
    install_item_service::satisfy_consume_item(&mut req, &e, drive, &mut ctx);
    module_owner::verify_ownership(&mut req, &e, &cap);
    request::complete_ignore(req);
    assert!(entity::has_module(&e, module_warp::module_name()));
    entity::destroy_for_testing(entity_test_utils::drain_modules(e));
    owner_cap::destroy_for_testing(cap);
    entity_test_utils::teardown_world(admin, registry);
}

#[test]
#[expected_failure(abort_code = module_registry::EModuleNotAllowed)]
fun core_attach_aborts_when_module_not_on_allowlist() {
    let mut ctx = tx_context::dummy();
    let (e, cap, registry, admin) = entity_test_utils::setup_in_space(&mut ctx);
    module_registry::assert_core_module_allowed<WarpModule>(&registry);
    owner_cap::destroy_for_testing(cap);
    entity::destroy_for_testing(e);
    entity_test_utils::teardown_world(admin, registry);
}

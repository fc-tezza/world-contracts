/// Energy module — capacity config in inner, live pool on entity accumulator.
///
/// - **Inner:** `max_capacity` (per-instance config).
/// - **Accumulator:** `Energy` on entity UID (`discharge` reads/writes the rolled-up pool).
/// - **Actions:** `energy:discharge` (`on_module<Discharge>` only; no owner requirement in POC).
/// - **Cross-module:** `attach` calls `module_flags::mark_connected` for the energy connection bit.
module world::module_energy;

use std::string::String;
use world::{
    action,
    entity,
    entity_accumulator,
    module_,
    module_attach,
    module_flags,
    request,
    requirement,
};

public struct EnergyModule has store {
    max_capacity: u64,
}

public struct Discharge has drop {}

const ACTION_VERSION: u64 = 1;

#[error(code = 0)]
const EUnsupportedActionVersion: vector<u8> = b"Unsupported energy action version";
#[error(code = 1)]
const EModuleNotInstalled: vector<u8> = b"Energy module instance not installed";

public fun action_version(): u64 {
    ACTION_VERSION
}

public fun module_name(): String {
    b"energy".to_string()
}

public fun install(
    entity: &mut entity::Entity,
    instance: String,
    max_capacity: u64,
    _ctx: &mut TxContext,
): request::Request {
    entity::install(entity, instance, EnergyModule { max_capacity }, _ctx);
    module_attach::attach_core_setup(entity)
}

public fun expose(entity: &mut entity::Entity, instance: String, version: u64) {
    assert!(version == ACTION_VERSION, EUnsupportedActionVersion);
    assert!(entity::has_module(entity, instance), EModuleNotInstalled);
    entity::expose(
        entity,
        b"energy:discharge".to_string(),
        action::new_versioned(version, vector[requirement::on_module<Discharge>(instance, vector[])]),
    );
}

public fun attach(entity: &mut entity::Entity, max_capacity: u64, ctx: &mut TxContext): request::Request {
    let instance = module_name();
    let req = install(entity, instance, max_capacity, ctx);
    expose(entity, instance, ACTION_VERSION);
    module_flags::mark_connected(entity, module_flags::energy_bit());
    req
}

#[test_only]
public fun destroy_installed(entity: &mut entity::Entity, name: String) {
    let EnergyModule { max_capacity: _ } =
        module_::take_inner(entity::remove_module_for_testing(entity, name));
}

public fun discharge(req: &mut request::Request, entity: &mut entity::Entity, amount: u64) {
    let instance = module_name();
    let energy = entity_accumulator::energy(entity.id());
    assert!(energy >= amount, 0);
    entity_accumulator::remove_energy(entity.id_mut(), amount);
    let (_, frame) = request::satisfy_on_module<EnergyModule, Discharge>(
        req,
        entity::borrow_module(entity, instance),
        internal::permit(),
    );
    request::enqueue(req, frame);
}

/// Beacon module — public, location-gated interact (POC example).
///
/// Models a "station / landmark / sector beacon": an action anyone can attempt if they
/// satisfy proximity to a fixed place, without an `OwnerCap`.
///
/// Flow:
/// - `install` stores `location_hash` in `BeaconModule.inner` (per instance in the Bag).
/// - `expose` reads that hash and registers `beacon:ping` with a single
///   `location_service::ProximityToLocation` requirement (configured at expose time).
/// - Client: `interact("beacon:ping")` → `location_service::verify_proximity` → `complete`.
///
/// `ping` is intentionally a no-op; the gate is satisfying the location requirement.
/// Does not use entity accumulators — only module inner + the entity-level location req.
///
/// Used in tests with inventory to demonstrate `expose_composite` merging requirements
/// from different modules (e.g. proximity + owner + deposit).
module world::module_beacon;

use std::string::String;
use world::{
    action,
    entity,
    location_service,
    module_,
    module_attach,
    request,
};

public struct BeaconModule has store {
    location_hash: vector<u8>,
}

const ACTION_VERSION: u64 = 1;

#[error(code = 0)]
const EUnsupportedActionVersion: vector<u8> = b"Unsupported beacon action version";
#[error(code = 1)]
const EModuleNotInstalled: vector<u8> = b"Beacon module instance not installed";

public fun action_version(): u64 {
    ACTION_VERSION
}

public fun module_name(): String {
    b"beacon".to_string()
}

public fun install(
    entity: &mut entity::Entity,
    instance: String,
    location_hash: vector<u8>,
    _ctx: &mut TxContext,
): request::Request {
    entity::install(entity, instance, BeaconModule { location_hash }, _ctx);
    module_attach::attach_core_setup(entity)
}

public fun expose(entity: &mut entity::Entity, instance: String, version: u64) {
    assert!(version == ACTION_VERSION, EUnsupportedActionVersion);
    assert!(entity::has_module(entity, instance), EModuleNotInstalled);
    let hash = entity::borrow_module<BeaconModule>(entity, instance)
        .inner(internal::permit())
        .location_hash;
    entity::expose(
        entity,
        b"beacon:ping".to_string(),
        action::new_versioned(version, vector[location_service::requirement(hash)]),
    );
}

public fun attach(entity: &mut entity::Entity, location_hash: vector<u8>, ctx: &mut TxContext): request::Request {
    let instance = module_name();
    let req = install(entity, instance, location_hash, ctx);
    expose(entity, instance, ACTION_VERSION);
    req
}

public fun ping(_req: &mut request::Request, _entity: &entity::Entity) {}

#[test_only]
public fun destroy_installed(entity: &mut entity::Entity, name: String) {
    let BeaconModule { location_hash: _ } =
        module_::take_inner(entity::remove_module_for_testing(entity, name));
}

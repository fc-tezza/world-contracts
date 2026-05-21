#[test_only]
/// Minimal module types for framework tests (no production gameplay).
module world::entity_test_support;

use std::string::String;
use world::{
    action,
    entity,
    module_,
    request,
    requirement,
};

public struct ProbeModule has store {
    n: u64,
}

public struct SlotA has drop {}
public struct SlotB has drop {}
public struct EntityGate has drop {}

public fun install_probe(
    entity: &mut entity::Entity,
    instance: String,
    n: u64,
    ctx: &mut TxContext,
) {
    entity::install(entity, instance, ProbeModule { n }, ctx);
}

/// Requirements `[EntityGate, SlotA]` — satisfied LIFO as SlotA then EntityGate.
public fun expose_two_slot_action(
    entity: &mut entity::Entity,
    action_name: String,
    instance: String,
) {
    entity::expose(
        entity,
        action_name,
        action::new_versioned(1, vector[
            requirement::on_entity<EntityGate>(vector[]),
            requirement::on_module<SlotA>(instance, vector[]),
        ]),
    );
}

public fun satisfy_slot_a(
    req: &mut request::Request,
    entity: &entity::Entity,
    instance: String,
) {
    let module_ = entity::borrow_module<ProbeModule>(entity, instance);
    let (_, frame) = request::satisfy_on_module<ProbeModule, SlotA>(
        req,
        module_,
        internal::permit(),
    );
    request::enqueue(req, frame);
}

public fun satisfy_slot_b(
    req: &mut request::Request,
    entity: &entity::Entity,
    instance: String,
) {
    let module_ = entity::borrow_module<ProbeModule>(entity, instance);
    let (_, frame) = request::satisfy_on_module<ProbeModule, SlotB>(
        req,
        module_,
        internal::permit(),
    );
    request::enqueue(req, frame);
}

public fun satisfy_entity_gate(req: &mut request::Request, entity: &entity::Entity) {
    let (_, frame) = request::satisfy_on_entity<EntityGate>(
        req,
        object::id(entity),
        internal::permit(),
    );
    request::enqueue(req, frame);
}

public fun probe_value(entity: &entity::Entity, instance: String): u64 {
    entity::borrow_module<ProbeModule>(entity, instance)
        .inner(internal::permit())
        .n
}

public fun destroy_probe(entity: &mut entity::Entity, instance: String) {
    let ProbeModule { n: _ } =
        module_::take_inner(entity::remove_module_for_testing<ProbeModule>(entity, instance));
}

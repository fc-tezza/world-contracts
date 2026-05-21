/// Universal entity shell (world_3 `structure` + `interact` on the same module).
module world::entity;

use std::{string::String, type_name};
use ptb::ptb;
use sui::{
    bag::{Self, Bag},
    dynamic_field as df,
    transfer::Receiving,
    vec_map::{Self, VecMap},
};
use world::{
    action::{Self, Action},
    admin_acl::AdminACL,
    entity_accumulator,
    module_::{Self, Module},
    owner_cap::{Self, OwnerCap},
    request::{Self, Request},
    requirement,
    system_auth,
};

public struct EntityKind has copy, drop, store {
    in_space: bool,
}

public struct Entity has key {
    id: UID,
    kind: EntityKind,
    owner_cap_id: ID,
    modules: Bag,
    actions: VecMap<String, Action>,
}

public struct InFlight() has copy, drop, store;

#[error(code = 0)]
const EModuleAlreadyAttached: vector<u8> = b"Module already attached";
#[error(code = 1)]
const EModuleNotAttached: vector<u8> = b"Module not attached";
#[error(code = 2)]
const EActionAlreadyExists: vector<u8> = b"Action already registered";
#[error(code = 3)]
const EInteractInFlight: vector<u8> = b"Entity already has interact in flight";
#[error(code = 4)]
const EEntityMismatch: vector<u8> = b"Request entity mismatch";
#[error(code = 5)]
const ENotAuthorized: vector<u8> = b"Not authorized";
#[error(code = 6)]
const EEntityNotEmpty: vector<u8> = b"Entity must have no modules or actions before destroy";

public(package) fun id(entity: &Entity): &UID { &entity.id }

public(package) fun id_mut(entity: &mut Entity): &mut UID { &mut entity.id }

public(package) fun actions(entity: &Entity): &VecMap<String, Action> {
    &entity.actions
}

public(package) fun actions_mut(entity: &mut Entity): &mut VecMap<String, Action> {
    &mut entity.actions
}

public fun object_id(entity: &Entity): ID { object::id(entity) }

public fun owner_cap_id(entity: &Entity): ID { entity.owner_cap_id }

public fun is_character(entity: &Entity): bool { !entity.kind.in_space }

public fun is_in_space(entity: &Entity): bool { entity.kind.in_space }

public fun has_module(entity: &Entity, name: String): bool {
    entity.modules.contains(name)
}

#[allow(lint(self_transfer))]
public fun create_in_space(ctx: &mut TxContext): (Entity, OwnerCap, Request) {
    create_with_kind(true, ctx)
}

#[allow(lint(self_transfer))]
public fun create_character(ctx: &mut TxContext): (Entity, OwnerCap, Request) {
    create_with_kind(false, ctx)
}

fun create_with_kind(in_space: bool, ctx: &mut TxContext): (Entity, OwnerCap, Request) {
    let uid = object::new(ctx);
    let entity_id = uid.to_inner();
    let cap = owner_cap::create(entity_id, ctx);
    let mut entity = Entity {
        id: uid,
        kind: EntityKind { in_space },
        owner_cap_id: object::id(&cap),
        modules: bag::new(ctx),
        actions: vec_map::empty(),
    };
    entity_accumulator::init_on_uid(&mut entity.id);

    let req = world::request::new_setup(
        entity_id,
        vector[system_auth::requirement()],
    );

    (entity, cap, req)
}

public fun share(entity: Entity) {
    transfer::share_object(entity);
}

/// Admin-only teardown of an empty entity shell (no modules, no registered actions).
public fun destroy_entity(
    entity: Entity,
    admin_acl: &AdminACL,
    ctx: &TxContext,
) {
    assert!(admin_acl.is_authorized_address(ctx.sender()), ENotAuthorized);
    let Entity { id, kind: _, owner_cap_id: _, modules, mut actions } = entity;
    assert!(modules.is_empty(), EEntityNotEmpty);
    let keys = actions.keys();
    keys.do!(|k| {
        let (_, action) = actions.remove(&k);
        action::destroy(action);
    });
    actions.destroy_empty();
    modules.destroy_empty();
    id.delete();
}

/// Install module inner state (`name` is the instance id; world_3 `structure::install`).
public fun install<M: store>(entity: &mut Entity, name: String, inner: M, _ctx: &mut TxContext) {
    assert!(!entity.modules.contains(name), EModuleAlreadyAttached);
    let module_ = module_::new(object::id(entity), name, inner);
    entity.modules.add(name, module_);
}

public fun borrow_module<M: store>(entity: &Entity, name: String): &Module<M> {
    assert!(entity.modules.contains(name), EModuleNotAttached);
    entity.modules.borrow(name)
}

public fun borrow_module_mut<M: store>(entity: &mut Entity, name: String): &mut Module<M> {
    assert!(entity.modules.contains(name), EModuleNotAttached);
    entity.modules.borrow_mut(name)
}

public fun receive_item<T: key + store>(
    entity: &mut Entity,
    receiving: Receiving<T>,
): T {
    transfer::public_receive(&mut entity.id, receiving)
}

// === Action registry (world_3 `expose`) ===

public fun expose(entity: &mut Entity, name: String, action: Action) {
    let actions = actions_mut(entity);
    assert!(!actions.contains(&name), EActionAlreadyExists);
    actions.insert(name, action);
}

public fun expose_composite(
    entity: &mut Entity,
    name: String,
    action_names: vector<String>,
    extra_requirements: vector<world::requirement::Requirement>,
) {
    let mut requirements = extra_requirements;
    let actions = actions(entity);
    action_names.do!(|action_name| {
        let entry = actions.get(&action_name);
        requirement::append_all(&mut requirements, entry.requirements());
    });
    expose(entity, name, world::action::new(requirements));
}

/// Start an interact flow (world_3 `structure::interact`).
public fun interact(entity: &mut Entity, name: String): Request {
    assert!(!df::exists_<InFlight>(entity.id(), InFlight()), EInteractInFlight);
    df::add(entity.id_mut(), InFlight(), true);

    let mut req = request::new_inflight(object::id(entity));
    let mut frame = request::frame();
    actions(entity).get(&name).requirements().do_ref!(|r| {
        request::require(&mut frame, *r);
    });
    request::enqueue(&mut req, frame);
    req
}

public fun complete(req: Request, ent: &mut Entity) {
    let entity_id = request::finish(req);
    assert!(entity_id == object::id(ent), EEntityMismatch);
    clear_inflight(ent);
}

fun clear_inflight(entity: &mut Entity) {
    let _: bool = df::remove(entity.id_mut(), InFlight());
}

// === PTB templates ===

fun package_id(): String {
    type_name::defining_id<Entity>().to_string()
}

public fun interact_template(
    ptb: &mut ptb::Transaction,
    mut args: vector<ptb::Argument>,
): vector<ptb::Argument> {
    assert!(args.length() == 1);
    let action_name = args.pop_back();
    let req = ptb.command(ptb::move_call(
        package_id(),
        b"entity".to_string(),
        b"interact".to_string(),
        vector[world::request::entity(), action_name],
        vector[],
    ));
    vector[req]
}

public fun complete_template(
    ptb: &mut ptb::Transaction,
    _args: vector<ptb::Argument>,
): vector<ptb::Argument> {
    ptb.command(ptb::move_call(
        package_id(),
        b"entity".to_string(),
        b"complete".to_string(),
        vector[world::request::request(), world::request::entity()],
        vector[],
    ));
    vector[]
}

#[test_only]
public fun has_interact_in_flight(entity: &Entity): bool {
    df::exists_(entity.id(), InFlight())
}

#[test_only]
public fun mark_inflight_for_testing(entity: &mut Entity) {
    if (!df::exists_(entity.id(), InFlight())) {
        df::add(entity.id_mut(), InFlight(), true);
    }
}

/// Drop an in-flight `Request` and clear the interact guard (simulates abandoning a stuck PTB).
#[test_only]
public fun abandon_interact(req: Request, entity: &mut Entity) {
    request::abandon(req);
    clear_inflight(entity);
}

#[test_only]
public fun remove_module_for_testing<M: store>(entity: &mut Entity, name: String): Module<M> {
    entity.modules.remove(name)
}

#[test_only]
public fun destroy_for_testing(e: Entity) {
    let Entity { id, kind: _, owner_cap_id: _, modules, mut actions } = e;
    let keys = actions.keys();
    keys.do!(|k| {
        let (_, action) = actions.remove(&k);
        action::destroy_for_testing(action);
    });
    actions.destroy_empty();
    modules.destroy_empty();
    id.delete();
}

#[test_only]
public fun action_count(entity: &Entity): u64 {
    actions(entity).length()
}

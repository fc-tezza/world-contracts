/// Inventory module — reference implementation for install / expose / accumulators.
///
/// - **Inner:** `items`, `max_slots`, `max_volume` (authoritative item list and per-instance caps).
/// - **Accumulators:** deposit/withdraw update `Mass` and `InventoryVolume` on the entity UID.
/// - **Actions:** `inventory:deposit`, `inventory:withdraw` (owner-gated + `on_module` slots).
/// - **Discovery:** announces `Deposit` / `Withdrawal` with `ptb_template_*` for devInspect clients.
///
/// `deposit` uses the entity path (inner + accumulators in one step); `deposit_module` is the
/// MVR-shaped variant for templates that pass `&Module<InventoryModule>`.
module world::module_inventory;

use std::{string::String, type_name};
use ptb::ptb;
use world::{
    action,
    discovery,
    entity,
    module_attach,
    entity_accumulator,
    item::{Self, Item},
    module_,
    module_flags,
    module_owner,
    request,
    requirement,
};

public struct InventoryModule has store {
    max_slots: u64,
    max_volume: u64,
    items: vector<Item>,
}

public struct Deposit has drop {}
public struct Withdrawal has drop {}

/// Action manifest version for `expose`.
const ACTION_VERSION: u64 = 1;

public fun action_version(): u64 {
    ACTION_VERSION
}

#[error(code = 0)]
const EStorageFull: vector<u8> = b"Inventory slot capacity exceeded";
#[error(code = 1)]
const EVolumeExceeded: vector<u8> = b"Inventory volume capacity exceeded";
#[error(code = 2)]
const EUnsupportedActionVersion: vector<u8> = b"Unsupported inventory action version";
#[error(code = 3)]
const EModuleNotInstalled: vector<u8> = b"Inventory module instance not installed";
public fun module_name(): String {
    b"inventory".to_string()
}

/// Install inventory inner state only (world_3 `install`).
public fun install(
    entity: &mut entity::Entity,
    instance: String,
    max_slots: u64,
    max_volume: u64,
    _ctx: &mut TxContext,
): request::Request {
    entity_accumulator::init_inventory_volume(entity.id_mut());
    entity::install(
        entity,
        instance,
        InventoryModule { max_slots, max_volume, items: vector[] },
        _ctx,
    );
    module_attach::attach_core_setup(entity)
}

/// Register inventory actions for an installed instance (world_3 `expose`).
public fun expose(entity: &mut entity::Entity, instance: String, version: u64) {
    assert!(version == ACTION_VERSION, EUnsupportedActionVersion);
    assert!(entity::has_module(entity, instance), EModuleNotInstalled);
    entity::expose(
        entity,
        b"inventory:deposit".to_string(),
        action::new_versioned(version, vector[
            module_owner::requirement(),
            requirement::on_module<Deposit>(instance, vector[]),
        ]),
    );
    entity::expose(
        entity,
        b"inventory:withdraw".to_string(),
        action::new_versioned(version, vector[
            module_owner::requirement(),
            requirement::on_module<Withdrawal>(instance, vector[]),
        ]),
    );
}

/// Convenience: install + expose + module graph hook (tests / demos).
public fun attach(
    entity: &mut entity::Entity,
    max_slots: u64,
    max_volume: u64,
    ctx: &mut TxContext,
): request::Request {
    let instance = module_name();
    let req = install(entity, instance, max_slots, max_volume, ctx);
    expose(entity, instance, ACTION_VERSION);
    module_flags::mark_connected(entity, 1);
    req
}

public fun max_volume(entity: &entity::Entity): u64 {
    max_volume_instance(entity, module_name())
}

public fun max_volume_instance(entity: &entity::Entity, instance: String): u64 {
    entity::borrow_module<InventoryModule>(entity, instance)
        .inner(internal::permit())
        .max_volume
}

public fun used_volume(entity: &entity::Entity): u64 {
    entity_accumulator::inventory_volume(entity.id())
}

public fun deposit(req: &mut request::Request, entity: &mut entity::Entity, item: Item) {
    deposit_instance(req, entity, module_name(), item)
}

public fun deposit_instance(
    req: &mut request::Request,
    entity: &mut entity::Entity,
    instance: String,
    item: Item,
) {
    let deposit_volume = item::total_volume(&item);
    let mass = item::total_mass(&item);
    let used = entity_accumulator::inventory_volume(entity.id());
    let max_vol = entity::borrow_module<InventoryModule>(entity, instance)
        .inner(internal::permit())
        .max_volume;
    assert!(used + deposit_volume <= max_vol, EVolumeExceeded);

    {
        let inv = entity::borrow_module_mut<InventoryModule>(entity, instance).inner_mut(internal::permit());
        let idx = inv.items.find_index!(|i| item::type_id(i) == item::type_id(&item));
        if (idx.is_some()) {
            item::merge(inv.items.borrow_mut(idx.destroy_some()), item);
        } else {
            assert!(inv.items.length() < inv.max_slots, EStorageFull);
            inv.items.push_back(item);
        };
    };
    entity_accumulator::add_mass(entity.id_mut(), mass);
    entity_accumulator::add_inventory_volume(entity.id_mut(), deposit_volume);

    let (_, frame) = request::satisfy_on_module<InventoryModule, Deposit>(
        req,
        entity::borrow_module(entity, instance),
        internal::permit(),
    );
    request::enqueue(req, frame);
}

/// MVR template: `request` + `module` + item (world_3 shape; accumulators via separate entity step if needed).
public fun deposit_module(
    req: &mut request::Request,
    module_: &mut module_::Module<InventoryModule>,
    item: Item,
) {
    let inv = module_.inner_mut(internal::permit());
    let idx = inv.items.find_index!(|i| item::type_id(i) == item::type_id(&item));
    if (idx.is_some()) {
        item::merge(inv.items.borrow_mut(idx.destroy_some()), item);
    } else {
        assert!(inv.items.length() < inv.max_slots, EStorageFull);
        inv.items.push_back(item);
    };
    let (_, frame) = request::satisfy_on_module<InventoryModule, Deposit>(
        req,
        module_,
        internal::permit(),
    );
    request::enqueue(req, frame);
}

public fun withdraw(
    req: &mut request::Request,
    entity: &mut entity::Entity,
    type_id: u64,
    quantity: u32,
    ctx: &mut TxContext,
): Item {
    withdraw_instance(req, entity, module_name(), type_id, quantity, ctx)
}

public fun withdraw_instance(
    req: &mut request::Request,
    entity: &mut entity::Entity,
    instance: String,
    type_id: u64,
    quantity: u32,
    ctx: &mut TxContext,
): Item {
    let withdrawn = {
        let inv = entity::borrow_module_mut<InventoryModule>(entity, instance).inner_mut(internal::permit());
        let idx = inv.items.find_index!(|i| item::type_id(i) == type_id);
        assert!(idx.is_some(), 0);
        let mut stored = inv.items.swap_remove(idx.destroy_some());
        let w = item::split(&mut stored, quantity, ctx);
        if (item::quantity(&stored) == 0) {
            item::destroy_zero(stored);
        } else {
            inv.items.push_back(stored);
        };
        w
    };
    let mass = item::total_mass(&withdrawn);
    let volume = item::total_volume(&withdrawn);
    entity_accumulator::remove_mass(entity.id_mut(), mass);
    entity_accumulator::remove_inventory_volume(entity.id_mut(), volume);

    let (_, frame) = request::satisfy_on_module<InventoryModule, Withdrawal>(
        req,
        entity::borrow_module(entity, instance),
        internal::permit(),
    );
    request::enqueue(req, frame);
    withdrawn
}

public fun withdraw_module(
    req: &mut request::Request,
    module_: &mut module_::Module<InventoryModule>,
    type_id: u64,
    quantity: u32,
    ctx: &mut TxContext,
): Item {
    let inv = module_.inner_mut(internal::permit());
    let idx = inv.items.find_index!(|i| item::type_id(i) == type_id);
    assert!(idx.is_some(), 0);
    let mut stored = inv.items.swap_remove(idx.destroy_some());
    let withdrawn = item::split(&mut stored, quantity, ctx);
    if (item::quantity(&stored) == 0) {
        item::destroy_zero(stored);
    } else {
        inv.items.push_back(stored);
    };
    let (_, frame) = request::satisfy_on_module<InventoryModule, Withdrawal>(
        req,
        module_,
        internal::permit(),
    );
    request::enqueue(req, frame);
    withdrawn
}

fun package_id(): String {
    type_name::defining_id<InventoryModule>().to_string()
}

#[allow(unused_function)]
fun ptb_template_deposit(mut ptb: ptb::Transaction): ptb::Transaction {
    ptb.command(ptb::move_call(
        package_id(),
        b"module_inventory".to_string(),
        b"deposit".to_string(),
        vector[
            world::request::request(),
            world::request::entity(),
            ptb::ext_input<request::PTB>(b"item".to_string()),
        ],
        vector[],
    ));
    ptb
}

#[allow(unused_function)]
fun ptb_template_withdraw(mut ptb: ptb::Transaction): ptb::Transaction {
    ptb.command(ptb::move_call(
        package_id(),
        b"module_inventory".to_string(),
        b"withdraw".to_string(),
        vector[
            world::request::request(),
            world::request::entity(),
            ptb::ext_input<request::PTB>(b"type_id".to_string()),
            ptb::ext_input<request::PTB>(b"quantity".to_string()),
        ],
        vector[],
    ));
    ptb
}

fun init(ctx: &mut TxContext) {
    discovery::announce_service(
        internal::permit<Deposit>(),
        b"Inventory Deposit".to_string(),
        b"Deposit an item into an installed inventory module".to_string(),
        b"ptb_template_deposit".to_string(),
        ctx,
    );
    discovery::announce_service(
        internal::permit<Withdrawal>(),
        b"Inventory Withdraw".to_string(),
        b"Withdraw quantity of an item type from inventory".to_string(),
        b"ptb_template_withdraw".to_string(),
        ctx,
    );
}

public fun deposit_template(
    ptb: &mut ptb::Transaction,
    mut args: vector<ptb::Argument>,
): vector<ptb::Argument> {
    assert!(args.length() == 1);
    let item = args.pop_back();
    ptb.command(ptb::move_call(
        package_id(),
        b"module_inventory".to_string(),
        b"deposit_module".to_string(),
        vector[world::request::request(), world::request::module_(), item],
        vector[],
    ));
    vector[]
}

#[test_only]
public fun destroy_installed(entity: &mut entity::Entity, name: String) {
    let inner = module_::take_inner(entity::remove_module_for_testing(entity, name));
    let InventoryModule { items, .. } = inner;
    items.destroy!(|i| item::destroy_for_testing(i));
}

public fun withdraw_template(
    ptb: &mut ptb::Transaction,
    mut args: vector<ptb::Argument>,
): vector<ptb::Argument> {
    assert!(args.length() == 2);
    let quantity = args.pop_back();
    let type_id = args.pop_back();
    let item = ptb.command(ptb::move_call(
        package_id(),
        b"module_inventory".to_string(),
        b"withdraw_module".to_string(),
        vector[world::request::request(), world::request::module_(), type_id, quantity],
        vector[],
    ));
    vector[item]
}

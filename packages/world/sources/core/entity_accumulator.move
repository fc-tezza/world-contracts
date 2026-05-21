/// Entity-scoped accumulators (custom mirror of sui::accumulator pattern).
module world::entity_accumulator;

use sui::dynamic_field as df;

public struct AccKey<phantom T> has copy, drop, store {}

public struct U64Cell has store {
    value: u64,
}

public struct Mass has drop {}
public struct Energy has drop {}
public struct Flags has drop {}
public struct InventoryVolume has drop {}

#[error(code = 0)]
const EAccumulatorMissing: vector<u8> = b"Accumulator not initialized";
#[error(code = 1)]
const EInsufficientValue: vector<u8> = b"Insufficient accumulator value";

fun acc_key<T>(): AccKey<T> { AccKey<T> {} }

public(package) fun init_on_uid(id: &mut UID) {
    ensure_u64<Mass>(id);
    ensure_u64<Energy>(id);
    ensure_u64<Flags>(id);
}

public(package) fun ensure_u64<T>(id: &mut UID) {
    if (!df::exists_<AccKey<T>>(id, acc_key<T>())) {
        df::add(id, acc_key<T>(), U64Cell { value: 0 });
    }
}

public(package) fun read_u64<T>(id: &UID): u64 {
    assert!(df::exists_<AccKey<T>>(id, acc_key<T>()), EAccumulatorMissing);
    df::borrow<AccKey<T>, U64Cell>(id, acc_key<T>()).value
}

public(package) fun merge_u64<T>(id: &mut UID, _: internal::Permit<T>, amount: u64) {
    ensure_u64<T>(id);
    let cell = df::borrow_mut<AccKey<T>, U64Cell>(id, acc_key<T>());
    cell.value = cell.value + amount;
}

public(package) fun split_u64<T>(id: &mut UID, _: internal::Permit<T>, amount: u64) {
    ensure_u64<T>(id);
    let cell = df::borrow_mut<AccKey<T>, U64Cell>(id, acc_key<T>());
    assert!(cell.value >= amount, EInsufficientValue);
    cell.value = cell.value - amount;
}

public(package) fun connect_bit(id: &mut UID, bit: u8) {
    let v = read_u64<Flags>(id);
    set_flags(id, internal::permit(), v | (1u64 << bit));
}

public(package) fun has_bit(id: &UID, bit: u8): bool {
    (read_u64<Flags>(id) & (1u64 << bit)) != 0
}

fun set_flags(id: &mut UID, _: internal::Permit<Flags>, mask: u64) {
    ensure_u64<Flags>(id);
    df::borrow_mut<AccKey<Flags>, U64Cell>(id, acc_key<Flags>()).value = mask;
}

public(package) fun add_mass(id: &mut UID, amount: u64) {
    merge_u64<Mass>(id, internal::permit(), amount);
}

public(package) fun remove_mass(id: &mut UID, amount: u64) {
    split_u64<Mass>(id, internal::permit(), amount);
}

public(package) fun add_energy(id: &mut UID, amount: u64) {
    merge_u64<Energy>(id, internal::permit(), amount);
}

public(package) fun remove_energy(id: &mut UID, amount: u64) {
    split_u64<Energy>(id, internal::permit(), amount);
}

public(package) fun init_inventory_volume(id: &mut UID) {
    ensure_u64<InventoryVolume>(id);
}

public(package) fun add_inventory_volume(id: &mut UID, amount: u64) {
    merge_u64<InventoryVolume>(id, internal::permit(), amount);
}

public(package) fun remove_inventory_volume(id: &mut UID, amount: u64) {
    split_u64<InventoryVolume>(id, internal::permit(), amount);
}

public fun inventory_volume(id: &UID): u64 {
    if (df::exists_<AccKey<InventoryVolume>>(id, acc_key<InventoryVolume>())) {
        read_u64<InventoryVolume>(id)
    } else {
        0
    }
}

public fun mass(id: &UID): u64 { read_u64<Mass>(id) }

public fun energy(id: &UID): u64 { read_u64<Energy>(id) }

public fun flags(id: &UID): u64 { read_u64<Flags>(id) }

/// Owned stackable item object (passed into inventory PTBs, stored in `InventoryModule`).
module world::item;

/// Demo item type for `install_item_service` custom-attach policy tests.
public fun attach_demo_item_type_id(): u64 {
    9001
}

public struct Item has key, store {
    id: UID,
    type_id: u64,
    quantity: u32,
    mass_per_unit: u64,
    volume_per_unit: u64,
}

#[error(code = 0)]
const EIncompatibleItem: vector<u8> = b"Items must match type, mass, and volume per unit";

public fun new(
    type_id: u64,
    quantity: u32,
    mass_per_unit: u64,
    volume_per_unit: u64,
    ctx: &mut TxContext,
): Item {
    Item { id: object::new(ctx), type_id, quantity, mass_per_unit, volume_per_unit }
}

public fun split(item: &mut Item, quantity: u32, ctx: &mut TxContext): Item {
    assert!(item.quantity() >= quantity);
    let new_item = Item {
        id: object::new(ctx),
        type_id: item.type_id,
        quantity,
        mass_per_unit: item.mass_per_unit,
        volume_per_unit: item.volume_per_unit,
    };
    item.quantity = item.quantity - quantity;
    new_item
}

public fun merge(item: &mut Item, another: Item) {
    let Item { id, type_id, quantity, mass_per_unit, volume_per_unit } = another;
    assert!(item.type_id() == type_id, EIncompatibleItem);
    assert!(item.mass_per_unit == mass_per_unit, EIncompatibleItem);
    assert!(item.volume_per_unit == volume_per_unit, EIncompatibleItem);
    item.quantity = item.quantity() + quantity;
    id.delete();
}

public fun destroy_zero(item: Item) {
    assert!(item.quantity() == 0);
    let Item { id, .. } = item;
    id.delete();
}

#[test_only]
public fun destroy_for_testing(item: Item) {
    let Item { id, .. } = item;
    id.delete();
}

public fun type_id(item: &Item): u64 { item.type_id }

public fun quantity(item: &Item): u32 { item.quantity }

public fun mass_per_unit(item: &Item): u64 { item.mass_per_unit }

public fun volume_per_unit(item: &Item): u64 { item.volume_per_unit }

public fun total_mass(item: &Item): u64 {
    (item.quantity as u64) * item.mass_per_unit
}

public fun total_volume(item: &Item): u64 {
    (item.quantity as u64) * item.volume_per_unit
}

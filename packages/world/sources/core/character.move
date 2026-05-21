module world::character;

use sui::transfer::Receiving;
use world::entity;

const EEntityMismatch: u64 = 0;
const EItemMismatch: u64 = 1;

public struct Borrow has copy, drop, store {
    entity_id: ID,
    item_id: ID,
}

public fun receive_item<T: key + store>(
    entity: &mut entity::Entity,
    cap: &world::owner_cap::OwnerCap,
    item: Receiving<T>,
): (T, Borrow) {
    assert!(entity::object_id(entity) == cap.entity_id_of(), EEntityMismatch);
    assert!(!entity::is_in_space(entity), EEntityMismatch);
    let item_obj = entity::receive_item(entity, item);
    let item_id = object::id(&item_obj);
    (item_obj, Borrow { entity_id: entity::object_id(entity), item_id })
}

public fun return_item<T: key + store>(item: T, borrow: Borrow) {
    let Borrow { entity_id, item_id } = borrow;
    assert!(object::id(&item) == item_id, EItemMismatch);
    transfer::public_transfer(item, entity_id.to_address());
}

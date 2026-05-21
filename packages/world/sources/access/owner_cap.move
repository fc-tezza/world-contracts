module world::owner_cap;

public struct OwnerCap has key, store {
    id: UID,
    entity_id: ID,
}

public fun create(entity_id: ID, ctx: &mut TxContext): OwnerCap {
    OwnerCap { id: object::new(ctx), entity_id }
}

public(package) fun transfer(owner_cap: OwnerCap, address: address) {
    transfer::public_transfer(owner_cap, address);
}

public fun transfer_to(cap: OwnerCap, recipient: address) {
    transfer::public_transfer(cap, recipient);
}

#[test_only]
public fun destroy_for_testing(cap: OwnerCap) {
    let OwnerCap { id, entity_id: _ } = cap;
    id.delete();
}

public fun entity_id_of(cap: &OwnerCap): ID { cap.entity_id }

public fun cap_object_id(cap: &OwnerCap): ID { object::id(cap) }

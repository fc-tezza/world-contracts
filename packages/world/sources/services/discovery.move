module world::discovery;

use std::{string::String, type_name::{Self, TypeName}};

public struct Tag()

public struct NewServiceAnnounced has copy, drop {
    package_id: ID,
    announcement_id: ID,
    requirement_type: TypeName,
}

public struct ServiceAnnouncement<phantom T: drop> has key {
    id: UID,
    package_id: ID,
    name: String,
    description: String,
    template_fun: String,
    requirement_type: TypeName,
}

public fun announce_service<T: drop>(
    _: internal::Permit<T>,
    name: String,
    description: String,
    template_fun: String,
    ctx: &mut TxContext,
) {
    let package_id = type_name::defining_id<T>();
    let requirement_type = type_name::with_defining_ids<T>();
    let id = object::new(ctx);

    sui::event::emit(NewServiceAnnounced {
        package_id: package_id.to_id(),
        announcement_id: id.to_inner(),
        requirement_type,
    });

    transfer::transfer(
        ServiceAnnouncement<T> {
            id,
            package_id: package_id.to_id(),
            name,
            description,
            template_fun,
            requirement_type,
        },
        package_id,
    )
}

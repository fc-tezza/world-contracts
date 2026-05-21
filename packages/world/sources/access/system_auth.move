/// System authorization marker (breaks `entity` ↔ `system_service` import cycle).
module world::system_auth;

use world::{
    discovery,
    request::{Self, Request, Frame},
    requirement::{Self, Requirement},
};

public struct SystemAuthorization has drop {}

public fun requirement(): Requirement {
    requirement::on_entity<SystemAuthorization>(vector[])
}

public fun satisfy(req: &mut Request, entity_id: ID): (Requirement, Frame) {
    request::satisfy_on_entity<SystemAuthorization>(req, entity_id, internal::permit())
}

/// `ptb_template` lives in `system_service`; announcement is emitted here for `Permit<T>`.
fun init(ctx: &mut TxContext) {
    discovery::announce_service(
        internal::permit<SystemAuthorization>(),
        b"System Authorization".to_string(),
        b"Requires an authorized admin ACL holder".to_string(),
        b"ptb_template".to_string(),
        ctx,
    )
}

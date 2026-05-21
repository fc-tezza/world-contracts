/// Core-module attach marker (breaks `module_owner` ↔ `module_registry` import cycle).
module world::core_module_auth;

use world::{
    request::{Self, Request, Frame},
    requirement::{Self, Requirement},
};

public struct CoreModuleAllowed has drop {}

public fun core_requirement(): Requirement {
    requirement::on_entity<CoreModuleAllowed>(vector[])
}

public fun satisfy(req: &mut Request, entity_id: ID): (Requirement, Frame) {
    request::satisfy_on_entity<CoreModuleAllowed>(req, entity_id, internal::permit())
}

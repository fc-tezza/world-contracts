/// Atomic checkbox of the request/requirement pattern (world_3 shape).
module world::requirement;

use std::{bcs, string::String, type_name::{Self, TypeName}};

public struct Requirement has copy, drop, store {
    type_name: TypeName,
    name: Option<String>,
    data: vector<u8>,
}

public fun new<T>(name: Option<String>, data: vector<u8>): Requirement {
    Requirement {
        type_name: type_name::with_original_ids<T>(),
        name,
        data,
    }
}

public fun from_config<T: drop>(name: Option<String>, c: T): Requirement {
    new<T>(name, bcs::to_bytes(&c))
}

public fun on_entity<T>(data: vector<u8>): Requirement {
    new<T>(option::none(), data)
}

public fun on_module<T>(module_name: String, data: vector<u8>): Requirement {
    new<T>(option::some(module_name), data)
}

public fun is<T>(requirement: &Requirement): bool {
    requirement.type_name == type_name::with_original_ids<T>()
}

public fun type_name(requirement: &Requirement): TypeName {
    requirement.type_name
}

public fun module_name(requirement: &Requirement): Option<String> {
    requirement.name
}

public fun data(requirement: &Requirement): vector<u8> {
    requirement.data
}

public(package) fun append_all(dst: &mut vector<Requirement>, src: &vector<Requirement>) {
    src.do_ref!(|r| dst.push_back(*r));
}

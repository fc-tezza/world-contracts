/// Installed module wrapper (world_3 `module_`; `name` == instance id on the entity).
module world::module_;

use std::string::String;

public struct Module<M> has store {
    entity: ID,
    name: String,
    inner: M,
}

public(package) fun new<M>(entity: ID, name: String, inner: M): Module<M> {
    Module { entity, name, inner }
}

public fun entity<M>(module_: &Module<M>): ID {
    module_.entity
}

public fun instance_name<M>(module_: &Module<M>): String {
    module_.name
}

public fun inner<M>(module_: &Module<M>, _: internal::Permit<M>): &M {
    &module_.inner
}

public fun inner_mut<M>(module_: &mut Module<M>, _: internal::Permit<M>): &mut M {
    &mut module_.inner
}

#[test_only]
/// Extract inner state after `entity::remove_module_for_testing` (only `module_` may destructure `Module`).
public fun take_inner<M: store>(module_: Module<M>): M {
    let Module { entity: _, name: _, inner } = module_;
    inner
}

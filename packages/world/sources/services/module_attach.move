/// Attach setup: owner + core allowlist, or owner + admin-configured custom requirements.
module world::module_attach;

use world::{
    core_module_auth,
    entity::Entity,
    module_owner,
    module_registry::{Self, ModuleRegistry},
    owner_cap::OwnerCap,
    requirement,
    request::{Self, Request},
};

/// Setup `Request` for core / first-party modules (`OwnerAuthorization` + `CoreModuleAllowed`).
public fun attach_core_setup(entity: &Entity): Request {
    request::new_setup(
        object::id(entity),
        vector[
            module_owner::requirement(),
            core_module_auth::core_requirement(),
        ],
    )
}

/// Setup `Request` for custom modules: owner + requirements configured on `ModuleRegistry`.
public fun attach_custom_setup<M: store>(entity: &Entity, registry: &ModuleRegistry): Request {
    let extra = module_registry::custom_attach_requirements<M>(registry);
    let mut reqs = vector[module_owner::requirement()];
    requirement::append_all(&mut reqs, extra);
    request::new_setup(object::id(entity), reqs)
}

public fun satisfy_core_module<M: store>(
    req: &mut Request,
    registry: &ModuleRegistry,
) {
    let frame = module_registry::satisfy_core_module<M>(req, registry);
    request::enqueue(req, frame);
}

#[test_only]
public fun finish_core_attach_for_testing<M: store>(
    req: Request,
    entity: &Entity,
    cap: &OwnerCap,
    registry: &ModuleRegistry,
) {
    let mut r = req;
    satisfy_core_module<M>(&mut r, registry);
    module_owner::verify_ownership(&mut r, entity, cap);
    request::complete_ignore(r);
}

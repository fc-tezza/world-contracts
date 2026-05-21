/// Metadata module — display fields in inner, owner-gated rename action.
///
/// - **Inner:** `display_name`, `tags` (local to this instance; not aggregated on UID).
/// - **Actions:** `metadata:set_name` (owner + `on_module<SetName>`).
/// - Typical on characters after `create_character`; in-space entities may omit it.
module world::module_metadata;

use std::string::String;
use world::{
    action,
    entity,
    module_,
    module_attach,
    module_owner,
    request,
    requirement,
};

public struct MetadataModule has store {
    display_name: String,
    tags: vector<u8>,
}

public struct SetName has drop {}

const ACTION_VERSION: u64 = 1;

#[error(code = 0)]
const EUnsupportedActionVersion: vector<u8> = b"Unsupported metadata action version";
#[error(code = 1)]
const EModuleNotInstalled: vector<u8> = b"Metadata module instance not installed";

public fun action_version(): u64 {
    ACTION_VERSION
}

public fun module_name(): String {
    b"metadata".to_string()
}

public fun install(
    entity: &mut entity::Entity,
    instance: String,
    display_name: String,
    _ctx: &mut TxContext,
): request::Request {
    entity::install(
        entity,
        instance,
        MetadataModule { display_name, tags: vector[] },
        _ctx,
    );
    module_attach::attach_core_setup(entity)
}

public fun expose(entity: &mut entity::Entity, instance: String, version: u64) {
    assert!(version == ACTION_VERSION, EUnsupportedActionVersion);
    assert!(entity::has_module(entity, instance), EModuleNotInstalled);
    entity::expose(
        entity,
        b"metadata:set_name".to_string(),
        action::new_versioned(version, vector[
            module_owner::requirement(),
            requirement::on_module<SetName>(instance, vector[]),
        ]),
    );
}

public fun attach(entity: &mut entity::Entity, display_name: String, ctx: &mut TxContext): request::Request {
    let instance = module_name();
    let req = install(entity, instance, display_name, ctx);
    expose(entity, instance, ACTION_VERSION);
    req
}

public fun set_name(req: &mut request::Request, entity: &mut entity::Entity, name: String) {
    let instance = module_name();
    entity::borrow_module_mut<MetadataModule>(entity, instance).inner_mut(internal::permit()).display_name =
        name;
    let (_, frame) = request::satisfy_on_module<MetadataModule, SetName>(
        req,
        entity::borrow_module(entity, instance),
        internal::permit(),
    );
    request::enqueue(req, frame);
}

#[test_only]
public fun destroy_installed(entity: &mut entity::Entity, name: String) {
    let MetadataModule { display_name: _, tags: _ } =
        module_::take_inner(entity::remove_module_for_testing(entity, name));
}

public fun display_name(entity: &entity::Entity): String {
    entity::borrow_module<MetadataModule>(entity, module_name())
        .inner(internal::permit())
        .display_name
}

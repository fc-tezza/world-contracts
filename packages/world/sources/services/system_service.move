module world::system_service;

use std::type_name;
use ptb::ptb;
use world::{
    admin_acl::AdminACL,
    entity,
    request,
    system_auth,
};

public fun is_authorized(req: &mut request::Request, entity: &entity::Entity, admin_acl: &AdminACL, ctx: &TxContext) {
    admin_acl.is_authorized_address(ctx.sender());
    let (_, frame) = system_auth::satisfy(req, object::id(entity));
    world::request::enqueue(req, frame);
}

#[allow(unused_function)]
fun ptb_template(mut ptb: ptb::Transaction): ptb::Transaction {
    let package_id = type_name::defining_id<system_auth::SystemAuthorization>().to_string();
    ptb.command(ptb::move_call(
        package_id,
        b"system_service".to_string(),
        b"is_authorized".to_string(),
        vector[
            world::request::request(),
            world::request::entity(),
            ptb::ext_input<request::PTB>(b"admin_acl".to_string()),
        ],
        vector[],
    ));
    ptb
}

#[test_only]
public fun authorize_for_testing(req: &mut request::Request, entity: &entity::Entity) {
    let (_, frame) = system_auth::satisfy(req, object::id(entity));
    world::request::enqueue(req, frame);
}

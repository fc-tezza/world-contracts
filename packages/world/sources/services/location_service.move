module world::location_service;

use std::type_name;
use ptb::ptb;
use world::{
    discovery,
    entity,
    request,
    requirement::{Self, Requirement},
};

public struct ProximityToLocation has drop { location_hash: vector<u8> }

public fun requirement(location_hash: vector<u8>): Requirement {
    requirement::from_config(option::none(), ProximityToLocation { location_hash })
}

public fun verify_proximity(req: &mut request::Request, entity: &entity::Entity, _proof: vector<u8>) {
    let (_, frame) = world::request::satisfy_on_entity<ProximityToLocation>(
        req,
        object::id(entity),
        internal::permit(),
    );
    world::request::enqueue(req, frame);
}

#[allow(unused_function)]
fun ptb_template(mut ptb: ptb::Transaction): ptb::Transaction {
    let package_id = type_name::defining_id<ProximityToLocation>().to_string();
    ptb.command(ptb::move_call(
        package_id,
        b"location_service".to_string(),
        b"verify_proximity".to_string(),
        vector[
            world::request::request(),
            world::request::entity(),
            ptb::ext_input<request::PTB>(b"proximity_proof".to_string()),
        ],
        vector[],
    ));
    ptb
}

fun init(ctx: &mut TxContext) {
    discovery::announce_service(
        internal::permit<ProximityToLocation>(),
        b"Physical Proximity".to_string(),
        b"Requires proximity proof".to_string(),
        b"ptb_template".to_string(),
        ctx,
    )
}

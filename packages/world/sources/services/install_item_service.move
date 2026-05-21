/// Optional attach/gameplay requirement: consume one unit of an `item` with a given `type_id`.
///
/// Admins include `install_item_service::requirement(type_id)` in a custom module's attach policy
/// (via `module_registry::set_custom_attach_policy`) to gate attachment on holding an item — without
/// hard-coding item checks in the registry.
module world::install_item_service;

use std::{bcs, type_name};
use ptb::ptb;
use world::{
    discovery,
    entity::Entity,
    item::{Self, Item},
    request::{Self, Request},
    requirement::{Self, Requirement},
};

public struct ConsumeInstallItem has drop {
    item_type_id: u64,
}

#[error(code = 0)]
const EWrongItemType: vector<u8> = b"Item type does not match install requirement";

public fun requirement(item_type_id: u64): Requirement {
    requirement::from_config(option::none(), ConsumeInstallItem { item_type_id })
}

/// Satisfy `ConsumeInstallItem` by consuming one unit (split) or the whole stack if quantity is 1.
public fun satisfy_consume_item(
    req: &mut Request,
    _entity: &Entity,
    item: Item,
    ctx: &mut TxContext,
) {
    let entity_id = req.entity_id();
    let (requirement, frame) = request::satisfy_on_entity<ConsumeInstallItem>(
        req,
        entity_id,
        internal::permit(),
    );
    let mut item = item;
    assert!(
        requirement.data() == bcs::to_bytes(&ConsumeInstallItem { item_type_id: item.type_id() }),
        EWrongItemType,
    );
    assert!(item.quantity() >= 1, EWrongItemType);
    if (item.quantity() == 1) {
        item::destroy_for_testing(item);
    } else {
        let piece = item::split(&mut item, 1, ctx);
        item::destroy_zero(piece);
        item::destroy_for_testing(item);
    };
    request::enqueue(req, frame);
}

#[allow(unused_function)]
fun ptb_template(mut ptb: ptb::Transaction): ptb::Transaction {
    let package_id = type_name::defining_id<ConsumeInstallItem>().to_string();
    ptb.command(ptb::move_call(
        package_id,
        b"install_item_service".to_string(),
        b"satisfy_consume_item".to_string(),
        vector[
            world::request::request(),
            world::request::entity(),
            ptb::ext_input<request::PTB>(b"install_item".to_string()),
        ],
        vector[],
    ));
    ptb
}

fun init(ctx: &mut TxContext) {
    discovery::announce_service(
        internal::permit<ConsumeInstallItem>(),
        b"Consume Install Item".to_string(),
        b"Requires consuming one unit of a registered item type".to_string(),
        b"ptb_template".to_string(),
        ctx,
    )
}

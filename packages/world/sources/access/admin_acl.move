module world::admin_acl;

use sui::table::{Self, Table};

public struct AdminACL has key {
    id: UID,
    authorized_addresses: Table<address, bool>,
}

#[error(code = 0)]
const ENotAuthorized: vector<u8> = b"Not authorized";

public fun add_authorized_address(admin_acl: &mut AdminACL, address: address, ctx: &TxContext) {
    assert!(is_authorized_address(admin_acl, ctx.sender()), ENotAuthorized);
    admin_acl.authorized_addresses.add(address, true);
}

public fun remove_authorized_address(admin_acl: &mut AdminACL, address: address, ctx: &TxContext) {
    assert!(is_authorized_address(admin_acl, ctx.sender()), ENotAuthorized);
    admin_acl.authorized_addresses.remove(address);
}

public fun is_authorized_address(admin_acl: &AdminACL, address: address): bool {
    admin_acl.authorized_addresses.contains(address)
}

fun init(ctx: &mut TxContext) {
    let mut admin_acl = AdminACL { id: object::new(ctx), authorized_addresses: table::new(ctx) };
    admin_acl.authorized_addresses.add(ctx.sender(), true);
    transfer::share_object(admin_acl);
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext): AdminACL {
    let mut admin_acl = AdminACL { id: object::new(ctx), authorized_addresses: table::new(ctx) };
    admin_acl.authorized_addresses.add(ctx.sender(), true);
    admin_acl
}

#[test_only]
public fun destroy_for_testing(admin_acl: AdminACL) {
    let AdminACL { id, authorized_addresses } = admin_acl;
    authorized_addresses.drop();
    id.delete();
}

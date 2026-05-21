/// In-flight request hot-potato for interact flows (world_3 shape).
module world::request;

use ptb::ptb;
use world::{module_, module_::Module, requirement::Requirement};

#[error(code = 0)]
const ERequirementsRemain: vector<u8> = b"Cannot complete: requirements remain";
#[error(code = 1)]
const EEntityMismatch: vector<u8> = b"Request entity mismatch";
#[error(code = 2)]
const EModuleMismatch: vector<u8> = b"Requirement module mismatch";
#[error(code = 3)]
const ERequirementTypeMismatch: vector<u8> = b"Requirement type mismatch";

public struct Request {
    entity: ID,
    requires: vector<Requirement>,
}

public struct Frame {
    pending: vector<Requirement>,
}

/// Namespace for PTB extended inputs (world_3 `request::PTB`).
public struct PTB() has drop;

public(package) fun new_inflight(entity: ID): Request {
    Request { entity, requires: vector[] }
}

public(package) fun new_setup(entity: ID, requires: vector<Requirement>): Request {
    Request { entity, requires }
}

public fun entity_id(req: &Request): ID {
    req.entity
}

public fun remaining(req: &Request): u64 {
    req.requires.length()
}

/// Consume a completed request; returns the entity id after validating no requirements remain.
public fun finish(req: Request): ID {
    let Request { entity, requires } = req;
    assert!(requires.length() == 0, ERequirementsRemain);
    entity
}

public fun frame(): Frame {
    Frame { pending: vector[] }
}

public fun require(frame: &mut Frame, requirement: Requirement) {
    frame.pending.push_back(requirement);
}

public fun enqueue(request: &mut Request, frame: Frame) {
    let Frame { pending } = frame;
    let mut i = 0;
    let len = pending.length();
    while (i < len) {
        request.requires.push_back(pending[i]);
        i = i + 1;
    };
}

public fun satisfy_on_module<M, T>(
    request: &mut Request,
    installed: &Module<M>,
    _: internal::Permit<T>,
): (Requirement, Frame) {
    let next = request.requires.pop_back();
    assert!(request.entity == module_::entity(installed), EEntityMismatch);
    assert!(next.module_name().is_some_and!(|n| n == module_::instance_name(installed)), EModuleMismatch);
    assert!(next.is<T>(), ERequirementTypeMismatch);
    (next, Frame { pending: vector[] })
}

public fun satisfy_on_entity<T>(
    request: &mut Request,
    entity_id: ID,
    _: internal::Permit<T>,
): (Requirement, Frame) {
    let next = request.requires.pop_back();
    assert!(request.entity == entity_id, EEntityMismatch);
    assert!(next.module_name().is_none(), EModuleMismatch);
    assert!(next.is<T>(), ERequirementTypeMismatch);
    (next, Frame { pending: vector[] })
}

/// PTB placeholder for the in-flight `Request` hot-potato (`world:request`).
public fun request(): ptb::Argument {
    ptb::ext_input<PTB>(b"world:request".to_string())
}

/// PTB placeholder for the shared entity shell (`world:entity`; world_3: `world:structure`).
public fun entity(): ptb::Argument {
    ptb::ext_input<PTB>(b"world:entity".to_string())
}

/// PTB placeholder for the module instance under operation (`world:module`; world_3).
public fun module_(): ptb::Argument {
    ptb::ext_input<PTB>(b"world:module".to_string())
}

#[test_only]
public(package) fun complete_ignore(r: Request) {
    let Request { .. } = r;
}

#[test_only]
/// Drop a `Request` without calling `finish` (abandoned interact).
public(package) fun abandon(r: Request) {
    let Request { .. } = r;
}

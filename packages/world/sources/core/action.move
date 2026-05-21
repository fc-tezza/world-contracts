/// Action manifest: requirements satisfied during an interact flow (world_3 shape).
module world::action;

use world::requirement::Requirement;

public struct Action has store {
    version: u64,
    requirements: vector<Requirement>,
}

const DEFAULT_VERSION: u64 = 1;

public fun default_version(): u64 {
    DEFAULT_VERSION
}

public fun new(requirements: vector<Requirement>): Action {
    new_versioned(DEFAULT_VERSION, requirements)
}

public fun new_versioned(version: u64, requirements: vector<Requirement>): Action {
    Action { version, requirements }
}

public fun version(action: &Action): u64 {
    action.version
}

public fun requirements(action: &Action): &vector<Requirement> {
    &action.requirements
}

public fun add_requirement(action: &mut Action, requirement: Requirement) {
    action.requirements.push_back(requirement);
}

public(package) fun destroy(action: Action) {
    let Action { version: _, requirements: _ } = action;
}

#[test_only]
public fun destroy_for_testing(action: Action) {
    destroy(action);
}

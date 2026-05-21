# Test coverage map

Tests are split by intent:

| File | Focus |
|------|--------|
| `entity_core_tests.move` | **Framework**: entity shell, bag attachment, `interact`/`Request` LIFO, guards, composite actions, accumulators, cross-module wiring |
| `entity_test_support.move` | Minimal `ProbeModule` + requirement markers for core tests (not production gameplay) |
| `entity_test_utils.move` | Shared setup/teardown helpers |
| `entity_tests.move` | Legacy integration smoke tests (kept; prefer extending `entity_core_tests` for new framework cases) |

## Framework coverage (`entity_core_tests`)

| Area | Tests |
|------|--------|
| **Entity shell** | `create_in_space_initializes_accumulators`, `create_character_differs_by_kind` |
| **Bag / install–expose** | `install_without_expose_registers_no_actions`, `expose_after_install_registers_action`, `duplicate_instance_name_on_install_aborts`, `two_named_instances_same_type_in_bag` |
| **Action / request flow** | `interact_lifo_satisfies_module_slot_before_entity_gate`, `interact_sets_in_flight_until_complete_or_abandon`, `interact_aborts_when_in_flight_already_set`, `complete_aborts_when_requirements_remain`, `satisfy_aborts_when_module_instance_does_not_match`, `satisfy_aborts_when_requirement_type_wrong` |

Cancelled / stuck interacts use `entity::abandon_interact` (test-only), which drops the `Request` and clears `InFlight` — closer to abandoning a failed PTB than `request::complete_ignore`.
| **Composite actions** | `expose_composite_unions_base_action_requirements` |
| **Accumulators** | `inventory_deposit_updates_entity_accumulators`, `withdraw_splits_entity_accumulators` |
| **Cross-module** | `flags_and_energy_attach_marks_connection_bit`, `owner_can_extend_action_requirements_cross_module`, `beacon_and_inventory_composite_interact_stack` |

## Gaps (intentionally light or deferred)

- Per-module action versioning (`EUnsupportedActionVersion`) — pattern is identical across `module_*`; covered once in inventory smoke tests
- `discovery` / `ptb_template` — off-chain devInspect; no Move unit tests
- `deposit_module` vs `deposit` accumulator split — documented in README; single entity-path test covers roll-up hypothesis
- Native Sui accumulators — not in POC

## Run

```bash
cd packages/world && sui move test -e testnet
```

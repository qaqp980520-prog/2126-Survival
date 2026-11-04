# Run 113 CI reconciliation

## Predecessor failures retained

- Candidate d16750ab66982f037c5a919773980d02d4ead82e: Run 113 focused #41777110220 passed the Orbital Surveyor import, rules and runtime smoke, then failed five bridge-test refresh-count assertions.
- Candidate d4b6dfb1a1bf7261a82428530568b85b5cf04c8f: the bridge snapshot reader was changed from get_property_list discovery to direct inventory.get("counts") access. The bridge count accessor test passed, but the same refresh-count assertions still failed.
- Log review showed the implementation emitted inventory_changed for the valid initial collection and valid drop as well as for mismatched operations. The expected refresh totals had omitted those valid-operation notifications; this was a test expectation error, not a new bridge runtime failure.

## Corrected assertion accounting

The regression now counts:
- 1 refresh from the valid initial collect.
- 1 additional refresh for each mismatched operation that actually changes the public counts Dictionary.
- No refresh for a no-op that reports a positive count but changes nothing.
- 1 refresh from the valid drop and 1 more from the subsequent mismatched drop.

The latest test assertions are on candidate 3a1fa016236056bbaaa71d0579aec1c59e576214. A fresh exact-head focused/full CI run is required; predecessor failures are not counted as passes.

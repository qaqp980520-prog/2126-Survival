# Run 113 method-only custom inventory fallback

Some legacy custom inventories expose get_item_count() but do not expose a public Dictionary named counts. The bridge preserves this contract and validates the operation's returned count, but cannot compare a hidden internal count before and after the call.

For this case:
- A valid finite whole-number result within 1..requested is accepted.
- A malformed result is rejected and does not emit item_collected/item_dropped/item_consumed.
- Because the bridge cannot know whether the custom implementation mutated hidden state before returning a malformed result, it emits inventory_changed defensively so listeners refresh rather than remain stale.
- The dedicated regression fixture verifies this behavior without adding a required method or changing save schema 1.

This is intentionally a compatibility fallback, not a transactional rollback guarantee for arbitrary third-party inventory implementations.

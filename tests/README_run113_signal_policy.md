# Run 113 inventory operation signal policy

- A valid collect/drop/consume emits the matching item event and inventory_changed.
- If a public counts Dictionary is observable, the bridge compares the reported amount with the actual before/after delta.
- A mismatch that changed the visible count emits inventory_changed so listeners refresh, but does not emit an item success event.
- A positive return with no actual count delta is rejected without an extra inventory_changed signal because the visible state did not change.
- If no public counts Dictionary exists, a valid sanitized return remains compatible. A malformed return emits a defensive inventory_changed refresh because the bridge cannot know whether hidden state changed; it never emits an item success event.
- This is a notification/sanitization contract, not a transactional rollback guarantee for arbitrary custom inventories.

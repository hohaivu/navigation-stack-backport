## Why

A performance audit of the pre-iOS-16 backport path in `NavigationStackBackport` identified 8 issues across view invalidation, type-erasure overhead, concurrency safety, and resource allocation. While the library is compact (~950 LOC) and delegates to native `NavigationStack` on iOS 16+, these issues compound in deep-stack or rapid push/pop scenarios on older devices, causing frame drops, animation glitches, and unnecessary CPU work.

## What Changes

- **Eliminate `AnyView` type-erasure** from `NavigationStack.body` and `NavigationLink.body` public surfaces to restore SwiftUI's structural diffing.
- **Fix shared singleton `EnvironmentKey.defaultValue`** for `NavigationAuthority` — use a computed property to prevent cross-stack state leaks.
- **Add change-detection guards** to preference-key side-effects in `DestinationModifier` and `PresentationModifier` to skip redundant `authority.update()` calls.
- **Serialize navigation updates** — replace unstructured `Task {}` in `NavigationUpdate.commit()` and `NavigationAuthority.update(id:presentation:)` with a coalesced, serialized approach to prevent animation races.
- **Cache `JSONEncoder`/`JSONDecoder`** as static instances in `NavigationPathItem` instead of allocating per call.
- **Remove force-unwrap** of `jsonValue.data(using: .utf8)!` in `LazyBox` for crash safety.
- **Index destinations by type name** for O(1) lookup instead of linear scan (minor).
- **Evaluate `layoutIfNeeded()`** in `UIKitNavigation.prelayout` for first-frame jank (minor).

## Capabilities

### New Capabilities
- `navigation-performance`: Performance improvements to the pre-iOS-16 backport path — covers type-erasure elimination, state isolation, preference-key efficiency, navigation update serialization, and resource caching.

### Modified Capabilities
_(none — no existing specs)_

## Impact

- **Code:** All 13 files in `Sources/NavigationStackBackport/`, with heaviest changes in `NavigationStack.swift`, `NavigationLink.swift`, `NavigationAuthority.swift`, `NavigationUpdate.swift`, `Destination.swift`, `Presentation.swift`, and `NavigationPathItem.swift`.
- **APIs:** `NavigationStack.body` and `NavigationLink.body` change from `AnyView` to opaque `some View` — **BREAKING** for anyone pattern-matching on the concrete `AnyView` return type (unlikely but technically public API).
- **Dependencies:** None added or removed.
- **Risk:** Medium — changes touch the core navigation engine. Requires verification of push/pop transitions, deep stacks, back-swipe gestures, and state restoration.

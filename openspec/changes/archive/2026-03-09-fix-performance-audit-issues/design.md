## Context

`NavigationStackBackport` (~950 LOC, 13 files) provides an iOS 15 backport of SwiftUI's `NavigationStack`. On iOS 16+ it thin-wraps native APIs with zero overhead. On iOS 15, it uses a `UINavigationController`-backed approach with `UIHostingController` per pushed screen, coordinated by a central `NavigationAuthority` object.

A performance audit identified 8 issues in the backport path. The codebase has no existing specs, tests, or CI — changes must be verified manually.

## Goals / Non-Goals

**Goals:**
- Eliminate unnecessary `AnyView` type-erasure from public API surfaces
- Prevent cross-stack state leaks via the shared `EnvironmentKey` default
- Reduce redundant work in preference-key callbacks
- Serialize navigation updates to prevent animation races
- Cache expensive Foundation objects (`JSONEncoder`/`JSONDecoder`)
- Fix crash-risk force-unwraps
- Maintain 100% API compatibility for consumers

**Non-Goals:**
- Changing behavior on iOS 16+ (all fixes target the pre-iOS-16 path only)
- Adding unit tests (separate effort)
- Optimizing the `CodableRepresentation` serialization format
- Changing the UIKit bridge architecture (e.g., replacing `UINavigationController`)

## Decisions

### D1: Eliminate `AnyView` from `NavigationStack` and `NavigationLink` public `body`

**Decision:** Change `public let body: AnyView` to a computed `@ViewBuilder public var body: some View` with `#available` branching inside the getter.

**Rationale:** `AnyView` disables SwiftUI's structural diff. Moving the branching into the `body` getter preserves the same runtime behavior while restoring type-level diffing. The `@ViewBuilder` return type is opaque to consumers, so this is source-compatible for typical usage.

**Alternative considered:** Keep `AnyView` but cache views per identity — rejected because it's more complex and still doesn't enable structural diffing.

### D2: Replace stored `EnvironmentKey.defaultValue` with computed property

**Decision:** Change `static var defaultValue = NavigationAuthority()` to `static var defaultValue: NavigationAuthority { NavigationAuthority() }`.

**Rationale:** A stored static creates a process-wide singleton that leaks state across unrelated `NavigationStack` instances. A computed property creates a fresh instance each time, which is harmless since `AuthorityView` always overrides it via `.environment()`.

### D3: Guard preference-key side-effects with change detection

**Decision:** In `DestinationModifier` and `PresentationModifier`, track the previous value passed to `authority.update()` and skip the call if the value hasn't changed.

**Rationale:** `transformPreference` runs on every layout pass. The current code performs dictionary mutations and potentially UIKit updates on every pass. Comparing before calling eliminates redundant work.

### D4: Coalesce navigation updates with `DispatchQueue.main.async`

**Decision:** Replace `Task { … }` in `NavigationUpdate.commit()` with `DispatchQueue.main.async { … }`. Add a serial gate in `NavigationAuthority` to coalesce rapid push/pop sequences into a single `setViewControllers` call.

**Rationale:** Unstructured `Task` captures the struct by value and can race with subsequent mutations. `DispatchQueue.main.async` provides a single-tick deferral without the overhead of a full task. A serial gate prevents interleaved animations.

**Alternative considered:** Actor-based serialization — rejected as over-engineering for this use case and would require making `NavigationAuthority` an actor (breaking change).

### D5: Static `JSONEncoder`/`JSONDecoder` in `NavigationPathItem`

**Decision:** Add `private static let encoder = JSONEncoder()` and `private static let decoder = JSONDecoder()` used by `EagerBox.encodePair` and `LazyBox.valueAs`.

**Rationale:** Foundation coder objects are expensive to allocate. Reusing a shared instance is safe since the library only uses default configuration.

### D6: Safe unwrap for `data(using: .utf8)`

**Decision:** Replace `jsonValue.data(using: .utf8)!` with a guard-let that returns `nil` on failure.

**Rationale:** While UTF-8 encoding failure from a `String` is theoretically impossible in Swift, force-unwraps are a crash risk and this is a zero-cost safety improvement.

## Risks / Trade-offs

- **[AnyView removal]** Changing `body` from stored `let` to computed `var` means the view is re-evaluated on each access. → **Mitigation:** This is how all standard SwiftUI views work; the cost is minimal and the diffing improvement far outweighs it.
- **[DispatchQueue vs Task]** Using `DispatchQueue.main.async` instead of `Task` loses structured concurrency benefits. → **Mitigation:** The operation is a UIKit mutation that must run on the main thread anyway. No cancellation or error propagation is needed.
- **[Serialization gate]** Coalescing updates could delay legitimate rapid transitions. → **Mitigation:** The gate only defers by one run-loop tick, same as the current `Task` approach. Net behavior is unchanged; ordering is just guaranteed.
- **[Static coders]** Shared `JSONEncoder`/`JSONDecoder` are not thread-safe if mutated. → **Mitigation:** We never mutate their properties. Access is read-only and safe.

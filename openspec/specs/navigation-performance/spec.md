## ADDED Requirements

### Requirement: Structural view diffing on public API surfaces
The `NavigationStack.body` and `NavigationLink.body` properties SHALL return `some View` via `@ViewBuilder` instead of `AnyView`, enabling SwiftUI's structural diffing on the pre-iOS-16 backport path.

#### Scenario: NavigationStack body returns opaque type
- **WHEN** a `NavigationStack` is initialized on iOS 15
- **THEN** its `body` property SHALL return an opaque `some View` type, not `AnyView`

#### Scenario: NavigationLink body returns opaque type
- **WHEN** a `NavigationLink` is initialized on iOS 15
- **THEN** its `body` property SHALL return an opaque `some View` type, not `AnyView`

#### Scenario: iOS 16+ path unchanged
- **WHEN** a `NavigationStack` or `NavigationLink` is initialized on iOS 16+
- **THEN** the library SHALL delegate to the native SwiftUI implementation with no additional wrapping

---

### Requirement: Isolated NavigationAuthority per stack
The `NavigationAuthorityKey.defaultValue` SHALL NOT share a singleton instance across multiple `NavigationStack` instances. Each access to the default value SHALL produce an independent instance.

#### Scenario: Two NavigationStacks in same app
- **WHEN** two `NavigationStack` instances exist simultaneously
- **THEN** each SHALL have an independent `NavigationAuthority` with no shared mutation

#### Scenario: Default value never used in practice
- **WHEN** `AuthorityView` sets the environment
- **THEN** the injected `@StateObject` authority SHALL override the default, and the default SHALL not retain state

---

### Requirement: Preference-key side-effect guards
`DestinationModifier` and `PresentationModifier` SHALL skip `authority.update()` calls when the value being reported has not changed since the previous layout pass.

#### Scenario: Repeated layout passes with no state change
- **WHEN** SwiftUI evaluates the preference tree multiple times without a binding change
- **THEN** `authority.update(id:destination:)` and `authority.update(id:presentation:)` SHALL NOT be called redundantly

#### Scenario: Actual state change triggers update
- **WHEN** a destination or presentation's bound state changes
- **THEN** the modifier SHALL call `authority.update()` with the new value

---

### Requirement: Serialized navigation updates
Navigation view-controller mutations SHALL be serialized so that rapid push/pop sequences do not race on `setViewControllers(_:animated:)`.

#### Scenario: Rapid push then pop
- **WHEN** a push immediately followed by a pop occurs within the same run-loop cycle
- **THEN** the navigation controller SHALL receive a single coalesced `setViewControllers` call with the correct final state

#### Scenario: Rapid push then push
- **WHEN** two push operations occur within the same run-loop cycle
- **THEN** the navigation controller SHALL receive a single `setViewControllers` call with both new view controllers in the correct order

#### Scenario: Normal single push
- **WHEN** a single push occurs
- **THEN** the navigation controller SHALL animate the transition normally with no extra delay

---

### Requirement: Cached JSON coders
`NavigationPathItem` SHALL use shared static `JSONEncoder` and `JSONDecoder` instances instead of allocating new ones per encode/decode operation.

#### Scenario: Encoding a path item
- **WHEN** `EagerBox.encodePair` is called
- **THEN** it SHALL use a shared static `JSONEncoder` instance

#### Scenario: Decoding a lazy path item
- **WHEN** `LazyBox.valueAs` is called for a `Decodable` type
- **THEN** it SHALL use a shared static `JSONDecoder` instance

---

### Requirement: Safe UTF-8 data conversion
`LazyBox.valueAs` SHALL NOT force-unwrap `jsonValue.data(using: .utf8)`. If the conversion fails, the function SHALL return `nil`.

#### Scenario: Valid JSON string
- **WHEN** `jsonValue` contains valid UTF-8 data
- **THEN** `valueAs` SHALL decode and return the value

#### Scenario: Hypothetical encoding failure
- **WHEN** `data(using: .utf8)` returns `nil`
- **THEN** `valueAs` SHALL return `nil` without crashing

---

### Requirement: Indexed destination lookup
`NavigationAuthority.view(for:index:)` SHALL use an indexed lookup by type rather than linearly scanning all registered destinations.

#### Scenario: Multiple destination types registered
- **WHEN** 5 destination types are registered and a path item of the 5th type is resolved
- **THEN** the lookup SHALL find the correct destination without checking all 4 preceding types

#### Scenario: No matching destination
- **WHEN** no registered destination accepts the path item
- **THEN** the function SHALL return a fallback warning view

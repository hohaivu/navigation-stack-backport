## 1. Eliminate AnyView Type-Erasure

- [x] 1.1 Refactor `NavigationStack.body` from `public let body: AnyView` to `@ViewBuilder public var body: some View` with `#available` branching inside the getter
- [x] 1.2 Refactor `NavigationLink.body` from `public let body: AnyView` to `@ViewBuilder public var body: some View` with `#available` branching inside the getter
- [x] 1.3 Remove stored init assignments that wrap in `AnyView()` from all `NavigationStack.init` and `NavigationLink.init` overloads

## 2. Fix NavigationAuthority State Isolation

- [x] 2.1 Change `NavigationAuthorityKey.defaultValue` from stored `static var` to computed property returning a fresh `NavigationAuthority()` each access

## 3. Preference-Key Side-Effect Guards

- [x] 3.1 Add previous-value tracking to `DestinationModifier` so `authority.update(id:destination:)` is skipped when the destination hasn't changed
- [x] 3.2 Add previous-value tracking to `PresentationModifier` so `authority.update(id:presentation:)` is skipped when `isPresented` and the view haven't changed

## 4. Serialize Navigation Updates

- [x] 4.1 Replace `Task { … }` in `NavigationUpdate.commit()` with `DispatchQueue.main.async`
- [x] 4.2 Replace `Task { @MainActor in … }` in `NavigationAuthority.update(id:presentation:)` with `DispatchQueue.main.async`
- [x] 4.3 Add a serial gate / pending-update coalescing mechanism to `NavigationAuthority` so rapid push/pop sequences produce a single `setViewControllers` call

## 5. Cache JSON Coders

- [x] 5.1 Add `private static let encoder = JSONEncoder()` to `NavigationPathItem` (or `EagerBox`)
- [x] 5.2 Add `private static let decoder = JSONDecoder()` to `NavigationPathItem` (or `LazyBox`)
- [x] 5.3 Replace inline `JSONEncoder()` / `JSONDecoder()` allocations with the cached instances

## 6. Safety & Minor Improvements

- [x] 6.1 Replace `jsonValue.data(using: .utf8)!` force-unwrap in `LazyBox.valueAs` with `guard let` returning `nil`
- [x] 6.2 Index destinations by type name in `NavigationAuthority` for O(1) lookup in `view(for:index:)`

## 7. Verification

- [x] 7.1 Build the package (`swift build`) to verify no compilation errors
- [x] 7.2 Verify iOS 16+ path still compiles and delegates to native APIs
- [x] 7.3 Review all public API surfaces for source compatibility

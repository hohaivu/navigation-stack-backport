import SwiftUI

public struct NavigationStack<Data, Root: View>: View {
	public var body: some View { makeBody() }

	private let makeBody: () -> AnyView
}

private extension NavigationStack {
	init(erasing view: some View) {
		makeBody = { AnyView(view) }
	}
}

extension NavigationStack where Data == NavigationPath {
	public init(@ViewBuilder root: () -> Root) {
		if #available(iOS 16.0, *) {
			self.init(erasing: SwiftUI.NavigationStack(root: root))
		} else {
			self.init(erasing: ImplicitStateView(root: root()))
		}
	}

	public init(path: Binding<NavigationPath>, @ViewBuilder root: () -> Root) {
		if #available(iOS 16.0, *) {
			self.init(erasing: SwiftUI.NavigationStack(path: path.swiftUIPath, root: root))
		} else {
			self.init(erasing: AuthorityView(path: path.storage, root: root()))
		}
	}
}

extension NavigationStack where Data: MutableCollection, Data: RandomAccessCollection, Data: RangeReplaceableCollection, Data.Element: Hashable {
	public init(path: Binding<Data>, @ViewBuilder root: () -> Root) {
		if #available(iOS 16.0, *) {
			self.init(erasing: SwiftUI.NavigationStack(path: path, root: root))
		} else {
			self.init(erasing: AuthorityView(path: Binding {
				NavigationPathBackport(items: path.wrappedValue.map { .init(value: $0) })
			} set: {
				path.wrappedValue = .init($0.items.compactMap { $0.valueAs(Data.Element.self) })
			}, root: root()))
		}
	}
}

private extension NavigationStack {
	struct ImplicitStateView: View {
		let root: Root
		@State private var path = NavigationPathBackport(items: [])

		var body: some View {
			AuthorityView(path: $path, root: root)
		}
	}

	struct AuthorityView: View {
		@Binding var path: NavigationPathBackport
		let root: Root

		@StateObject private var authority = NavigationAuthority()

		var body: some View {
			UIKitNavigation(root: root.environment(\.navigationContextId, 0), path: path)
				.ignoresSafeArea()
				.environment(\.navigationAuthority, authority)
				.onPreferenceChange(DestinationIDsKey.self) { authority.destinationIds = $0 }
				.onPreferenceChange(PresentationIDsKey.self) { authority.presentationIds = $0 }
				.onReceive(authority.pathPopPublisher) { path.removeLast(path.count - $0) }
				.onReceive(authority.pathPushPublisher) { path.items.append($0) }
		}
	}
}

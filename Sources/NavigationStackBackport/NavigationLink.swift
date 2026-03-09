import SwiftUI

public struct NavigationLink<Label: View>: View {
	public var body: some View { makeBody() }

	private let makeBody: () -> AnyView
}

private extension NavigationLink {
	init(erasing view: some View) {
		makeBody = { AnyView(view) }
	}
}

public extension NavigationLink {
	init<P: Hashable>(value: P?, @ViewBuilder label: () -> Label) {
		if #available(iOS 16.0, *) {
			self.init(erasing: SwiftUI.NavigationLink(value: value, label: label))
		} else {
			self.init(erasing: BackportLink(label: label(), item: value.map { .init(value: $0) }))
		}
	}

	init<P: Hashable>(value: P?, @ViewBuilder label: () -> Label) where P: Codable {
		if #available(iOS 16.0, *) {
			self.init(erasing: SwiftUI.NavigationLink(value: value, label: label))
		} else {
			self.init(erasing: BackportLink(label: label(), item: value.map { .init(value: $0) }))
		}
	}

	init<P: Hashable>(_ titleKey: LocalizedStringKey, value: P?) where Label == Text {
		if #available(iOS 16.0, *) {
			self.init(erasing: SwiftUI.NavigationLink(titleKey, value: value))
		} else {
			self.init(erasing: BackportLink(label: Text(titleKey), item: value.map { .init(value: $0) }))
		}
	}

	init<P: Hashable>(_ titleKey: LocalizedStringKey, value: P?) where Label == Text, P: Codable {
		if #available(iOS 16.0, *) {
			self.init(erasing: SwiftUI.NavigationLink(titleKey, value: value))
		} else {
			self.init(erasing: BackportLink(label: Text(titleKey), item: value.map { .init(value: $0) }))
		}
	}

	init<P: Hashable, S>(_ title: S, value: P?) where Label == Text, S: StringProtocol {
		if #available(iOS 16.0, *) {
			self.init(erasing: SwiftUI.NavigationLink(title, value: value))
		} else {
			self.init(erasing: BackportLink(label: Text(title), item: value.map { .init(value: $0) }))
		}
	}

	init<P: Hashable, S>(_ title: S, value: P?) where Label == Text, S: StringProtocol, P: Codable {
		if #available(iOS 16.0, *) {
			self.init(erasing: SwiftUI.NavigationLink(title, value: value))
		} else {
			self.init(erasing: BackportLink(label: Text(title), item: value.map { .init(value: $0) }))
		}
	}
}

private extension NavigationLink {
	struct BackportLink: View {
		let label: Label
		let item: NavigationPathItem?
		@Environment(\.navigationAuthority) private var authority

		var body: some View {
			Button {
				guard let item else { return }
				authority.pathPushPublisher.send(item)
			} label: {
				label
			}
			.disabled(item == nil || !authority.canNavigate)
		}
	}
}

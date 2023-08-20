//
//  PreferencesSidebarMenu.swift
//  PreferencesWindow
//

import Cocoa
import SFSafeSymbols

enum PreferencesSidebarMenuSection: Hashable {
    case menu
}

public protocol PreferencesView: NSView {
    func willShow()
}

public struct PreferencesSidebarMenuItem: Hashable {
    public let id = UUID()

    public let title: String
    public let symbol: SFSymbol
    public let view: any PreferencesView

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }

    public static func == (lhs: PreferencesSidebarMenuItem, rhs: PreferencesSidebarMenuItem) -> Bool {
        return lhs.id == rhs.id
    }

    public init(title: String, symbol: SFSymbol, view: any PreferencesView) {
        self.title = title
        self.symbol = symbol
        self.view = view
    }
}

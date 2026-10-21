// ThemeManager.swift
// ReclaimUI/DesignSystem
//
// Observable theme manager for the single, authentic Retro Tech (C++ IDE) appearance.

import SwiftUI

@MainActor
public final class ThemeManager: ObservableObject {
    @Published public var currentTheme: any Theme

    public init(theme: any Theme = HackerTheme()) {
        self.currentTheme = theme
    }

    public func switchToHacker() {
        self.currentTheme = HackerTheme()
    }
}

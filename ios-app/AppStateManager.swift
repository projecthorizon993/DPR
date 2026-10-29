//
//  AppStateManager.swift
//  CameraApp
//

import Foundation

final class AppStateManager: ObservableObject {
    static let shared = AppStateManager()

    @Published var isAppActive = false
    @Published var autoHideControls = true

    private init() {}

    func applicationDidBecomeActive() {
        isAppActive = true
    }

    func applicationDidEnterBackground() {
        isAppActive = false
    }

    func applicationWillResignActive() {
        isAppActive = false
    }
}

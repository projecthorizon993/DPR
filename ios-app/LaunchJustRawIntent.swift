//
//  LaunchJustRawIntent.swift
//  CameraApp
//

import Foundation
import AppIntents

struct LaunchJustRawIntent: AppIntent {
    static var title: LocalizedStringResource = "Launch JustRaw"
    static var description = IntentDescription("Launch the JustRaw camera app")

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

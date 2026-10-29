//
//  ErrorHandler.swift
//  CameraApp
//

import Foundation
import SwiftUI

enum ErrorCategory: String, CaseIterable {
    case camera
    case permissions
    case fileSystem
    case unknown
}

enum ErrorSeverity: String, CaseIterable {
    case low
    case medium
    case high
    case critical
}

struct CameraError: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let category: ErrorCategory
    let severity: ErrorSeverity
}

final class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()

    @Published var showingErrorAlert = false
    @Published var currentErrors: [CameraError] = []

    private init() {}

    func handleError(_ error: Error, category: ErrorCategory = .camera, severity: ErrorSeverity = .high, context: [String: String] = [:]) {
        let error = CameraError(
            message: error.localizedDescription,
            category: category,
            severity: severity
        )
        DispatchQueue.main.async {
            self.currentErrors.append(error)
            self.showingErrorAlert = true
        }
        Logger.shared.error("Handled error: \(error.localizedDescription) [\(category.rawValue)] [\(severity.rawValue)]", context: context)
    }

    func clearAllErrors() {
        DispatchQueue.main.async {
            self.currentErrors.removeAll()
            self.showingErrorAlert = false
        }
    }
}

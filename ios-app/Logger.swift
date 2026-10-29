//
//  Logger.swift
//  CameraApp
//
//  Comprehensive logging system
//

import Foundation

enum LogLevel: String {
    case DEBUG = "DEBUG"
    case INFO = "INFO"
    case WARN = "WARN"
    case ERROR = "ERROR"
    case FATAL = "FATAL"
}

final class Logger {
    static let shared = Logger()
    private let logFileURL: URL
    private let queue = DispatchQueue(label: "com.cameraapp.logger", qos: .utility)
    private let dateFormatter: DateFormatter

    private init() {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logsDir = documentsDir.appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true, attributes: nil)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        self.logFileURL = logsDir.appendingPathComponent("camera_app_\(timestamp).log")

        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        self.log(level: .INFO, message: "CameraApp launched", file: "main", function: "init", line: 0)
    }

    func log(level: LogLevel, message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let timestamp = dateFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let logEntry = "\(timestamp) [\(level.rawValue)] [\(fileName):\(line)] \(function): \(message)\n"

        queue.async {
            if let data = logEntry.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: self.logFileURL.path) {
                    if let fileHandle = try? FileHandle(forWritingTo: self.logFileURL) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } else {
                    try? data.write(to: self.logFileURL, options: .atomic)
                }
            }
        }
    }

    // MARK: - Convenience logging methods

    func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .DEBUG, message: message, file: file, function: function, line: line)
    }

    func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .INFO, message: message, file: file, function: function, line: line)
    }

    func logWarn(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .WARN, message: message, file: file, function: function, line: line)
    }

    func logError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .ERROR, message: message, file: file, function: function, line: line)
    }

    func logFatal(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .FATAL, message: message, file: file, function: function, line: line)
    }

    // Compatibility methods with module/operation/details signature
    func info(module: String, operation: String, details: String, file: String = #file, function: String = #function, line: Int = #line) {
        logInfo("[\(module)] \(operation): \(details)", file: file, function: function, line: line)
    }

    func warning(module: String, operation: String, details: String, file: String = #file, function: String = #function, line: Int = #line) {
        logWarn("[\(module)] \(operation): \(details)", file: file, function: function, line: line)
    }

    func error(module: String, operation: String, details: String, file: String = #file, function: String = #function, line: Int = #line) {
        logError("[\(module)] \(operation): \(details)", file: file, function: function, line: line)
    }

    // Additional convenience aliases
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logInfo(message, file: file, function: function, line: line)
    }

    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logDebug(message, file: file, function: function, line: line)
    }

    func warn(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logWarn(message, file: file, function: function, line: line)
    }

    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logError(message, file: file, function: function, line: line)
    }

    // MARK: - Camera-specific logging methods

    func logCameraSessionStart() {
        logInfo("Camera session started", file: "CameraService", function: "startSession", line: 0)
    }

    func logCameraSessionStop() {
        logInfo("Camera session stopped", file: "CameraService", function: "stopSession", line: 0)
    }

    func logCameraSessionError(_ error: Error) {
        logError("Camera session error: \(error.localizedDescription)", file: "CameraService", function: "configureSession", line: 0)
    }

    func logPhotoCapture(mode: String, success: Bool) {
        logInfo("Photo capture: mode=\(mode), success=\(success)", file: "CameraService", function: "capturePhoto", line: 0)
    }

    func logFlashToggle(enabled: Bool) {
        logInfo("Flash toggled: \(enabled ? "on" : "off")", file: "CameraViewModel", function: "toggleFlash", line: 0)
    }

    func logFocusSet(point: CGPoint, success: Bool) {
        logInfo("Focus set at (\(String(format: "%.2f", point.x)), \(String(format: "%.2f", point.y))), success=\(success)", file: "CameraViewModel", function: "setFocusPoint", line: 0)
    }

    func logZoomSet(level: Float, success: Bool) {
        logInfo("Zoom set to \(String(format: "%.2f", level))x, success=\(success)", file: "CameraViewModel", function: "setZoomFactor", line: 0)
    }

    func logCameraSwitch(to position: String) {
        logInfo("Camera switched to \(position)", file: "CameraService", function: "switchCamera", line: 0)
    }

    // MARK: - App lifecycle logging

    func logAppLaunch() {
        logInfo("App launched", file: "CameraApp", function: "init", line: 0)
    }

    func logAppForeground() {
        logInfo("App foregrounded", file: "CameraApp", function: "applicationDidBecomeActive", line: 0)
    }

    func logAppBackground() {
        logInfo("App backgrounded", file: "CameraApp", function: "applicationDidEnterBackground", line: 0)
    }

    func logAppTerminate() {
        logInfo("App terminated", file: "CameraApp", function: "applicationWillTerminate", line: 0)
    }

    // MARK: - General

    func getLogFileURL() -> URL? {
        return logFileURL
    }

    func clearLogs() {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logsDir = documentsDir.appendingPathComponent("Logs", isDirectory: true)
        if let files = try? FileManager.default.contentsOfDirectory(at: logsDir, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "log" {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}

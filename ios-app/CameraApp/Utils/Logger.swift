//
//  Logger.swift
//  CameraApp
//
//  Comprehensive logging system - writes to app Documents directory
//  for retrieval via iTunes File Sharing or iLoader
//

import Foundation

/// Logging levels
enum LogLevel: String {
    case DEBUG = "DEBUG"
    case INFO = "INFO"
    case WARN = "WARN"
    case ERROR = "ERROR"
    case FATAL = "FATAL"
}

/// Logger that writes to app Documents directory
final class Logger {
    static let shared = Logger()
    private let fileManager = FileManager.default
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
    
    func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .INFO, message: message, file: file, function: function, line: line)
    }
    
    func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .DEBUG, message: message, file: file, function: function, line: line)
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
    
    // MARK: - Photo save logging
    
    func logPhotoSave(start: Bool, imageCount: Int = 1) {
        logInfo("Photo save \(start ? "started" : "completed"): \(imageCount) image(s)", file: "PhotoSaveService", function: "savePhoto", line: 0)
    }
    
    // MARK: - General
    
    func getLogFileURL() -> URL? {
        return logFileURL
    }
    
    func getAllLogFiles() -> [URL] {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logsDir = documentsDir.appendingPathComponent("Logs", isDirectory: true)
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: logsDir, includingPropertiesForKeys: nil) else {
            return []
        }
        return files.filter { $0.pathExtension == "log" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
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

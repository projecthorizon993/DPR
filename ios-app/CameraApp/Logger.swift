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
        // Create logs directory in Documents
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logsDir = documentsDir.appendingPathComponent("Logs", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true, attributes: nil)
        
        // Create log file with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        self.logFileURL = logsDir.appendingPathComponent("camera_app_\(timestamp).log")
        
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        // Write initial log
        self.log(level: .INFO, message: "CameraApp launched", file: "main", function: "init", line: 0)
    }

    /// Log a message with details
    func log(level: LogLevel, message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let timestamp = dateFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let logEntry = "\(timestamp) [\(level.rawValue)] [\(fileName):\(line)] \(function): \(message)\n"

        // Write to file asynchronously
        queue.async {
            if let data = logEntry.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: self.logFileURL.path) {
                    // Append to existing file
                    if let fileHandle = try? FileHandle(forWritingTo: self.logFileURL) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } else {
                    // Create new file
                    try? data.write(to: self.logFileURL, options: .atomic)
                }
            }
        }
    }

    /// Get the log file URL for sharing
    func getLogFileURL() -> URL? {
        return logFileURL
    }

    /// Get all log files
    func getAllLogFiles() -> [URL] {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logsDir = documentsDir.appendingPathComponent("Logs", isDirectory: true)
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: logsDir, includingPropertiesForKeys: nil) else {
            return []
        }
        return files.filter { $0.pathExtension == "log" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Clear all logs
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

// MARK: - Convenience logging functions

func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.log(level: .DEBUG, message: message, file: file, function: function, line: line)
}

func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.log(level: .INFO, message: message, file: file, function: function, line: line)
}

func logWarn(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.log(level: .WARN, message: message, file: file, function: function, line: line)
}

func logError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.log(level: .ERROR, message: message, file: file, function: function, line: line)
}

func logFatal(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.log(level: .FATAL, message: message, file: file, function: function, line: line)
}
//
//  misc.swift
//  LinkMapAnalyzer
//
//  Created by SolaWing on 2022/11/12.
//

import Foundation

enum Logging: UInt8 {
    case debug = 1, info, warn, error
    @inlinable
    func callAsFunction(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        Logging.log(message: message(), level: self, file: file, line: line)
    }
    @inlinable
    static func log(message: @autoclosure () -> String, level: Logging = .info, file: String = #file, line: Int = #line) {
        if level.rawValue < Logging.debug.rawValue { return }
        print("[\(level)] \(file):\(line): \(message())")
    }
}

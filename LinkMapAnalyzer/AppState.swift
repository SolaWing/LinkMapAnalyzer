//
//  AppState.swift
//  LinkMapAnalyzer
//
//  Created by SolaWing on 2022/11/12.
//

import SwiftUI

class AppState: ObservableObject {
    @Published var selectedFile: String = "" {
        didSet {
            tip = nil
            do {
                Logging.info("update path at \(selectedFile)")
                linkmap = try LinkMap.analyze(path: selectedFile)
                updateOutput()
            } catch {
                tip = (error.localizedDescription, .red)
            }
        }
    }
    var tip: (String, Color)?
    var linkmap: LinkMap?
    lazy var availableLinkMapFiles = LinkMap.availableLinkMapFiles()
    var sizeInfo: ([Row], String)? // row, summary
    struct Row: Identifiable {
        // var id = UUID() // avoid diff and animation crash
        var id: String
        var size: Int
        var name: String
        var sizeStr: String {
            AppState.format(num: size)
        }
    }

    func updateOutput() {
        guard let linkmap else { sizeInfo = nil; return }
        let rows = linkmap.indexes.values
            .map { Row(id: $0.path, size: $0.total, name: URL(fileURLWithPath: $0.path).lastPathComponent) }
            .sorted(key: { -$0.size })
        let total = rows.map(\.size).reduce(0, +)
        sizeInfo = (rows, "总大小：\(AppState.format(num: total))")
        Logging.debug("updateOutput")
    }

    static func format(num: Int) -> String {
        if num < 1024 { // 4KB
          return "\(num) B"
        }
        else if num < 1024 * 1024 { // 1MB
            return  String(format: "%.2f KB", Double(num) / 1024.0)
        }
        else {
            return String(format: "%.2f MB", Double(num) / 1024.0 / 1024.0)
        }
    }
}


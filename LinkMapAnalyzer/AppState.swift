//
//  AppState.swift
//  LinkMapAnalyzer
//
//  Created by SolaWing on 2022/11/12.
//

import SwiftUI

@MainActor
class AppState: ObservableObject {
    var selectedFile: String = "" {
        didSet {
            if selectedFile == oldValue { return }
            Logging.info("update path at \(selectedFile)")
            manualChoose.insert(selectedFile, at: 0)
            manualChoose = manualChoose.unique()
            let loading = Task { [selectedFile] in
                do {
                    let begin = CACurrentMediaTime()
                    let linkmap = try await LinkMap.analyze(path: selectedFile)
                    if Task.isCancelled { return }
                    let anaEnd = CACurrentMediaTime()
                    let sizeInfo = await AppState.updateOutput(linkmap: linkmap)
                    Logging.info("updated path at \(URL(fileURLWithPath: selectedFile).lastPathComponent): analyze: \(anaEnd - begin)s, output: \(CACurrentMediaTime() - anaEnd)")
                    (self.linkmap, self.sizeInfo) = (linkmap, sizeInfo)
                    tip = nil
                } catch {
                    if Task.isCancelled { return }
                    tip = (error.localizedDescription, .red)
                }
                self.loading = nil
            }
            tip = ("loading", .gray)
            self.loading = { loading.cancel() }
        }
    }
    @Published var loading: (() -> Void)? {
        willSet { loading?() }
    }
    var tip: (String, Color)?
    var manualChoose: [String] = []
    var fileToBeSelect: [String] { (manualChoose + LinkMap.availableLinkMapFiles()).unique() }

    var linkmap: LinkMap?
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

    nonisolated static func updateOutput(linkmap: LinkMap) async -> ([Row], String) {
        let rows = linkmap.indexes.values
            .map { Row(id: $0.path, size: $0.total, name: URL(fileURLWithPath: $0.path).lastPathComponent) }
            .sorted(key: { -$0.size })
        let total = rows.map(\.size).reduce(0, +)
        let sizeInfo = (rows, "总大小：\(AppState.format(num: total))")
        Logging.debug("updateOutput")
        return sizeInfo
    }

    nonisolated static func format(num: Int) -> String {
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


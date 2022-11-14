//
//  AppState.swift
//  LinkMapAnalyzer
//
//  Created by SolaWing on 2022/11/12.
//

import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    // let objectWillChange = ObservableObjectPublisher()
    var bags = [AnyCancellable]()
    init() {
        $query.debounce(for: 1, scheduler: RunLoop.main).sink { (_) in
            self.updateQuery()
        }.store(in: &bags)
    }
    // MARK: input
    var manualChoose: [String] = []
    var selectedFile: String = "" {
        didSet {
            if selectedFile == oldValue { return }
            Logging.info("update path at \(selectedFile)")
            manualChoose.insert(selectedFile, at: 0)
            manualChoose = manualChoose.unique()
            self.linkmap = nil // 为空时屏蔽其他的loading
            loading { [self, selectedFile] in
                let begin = CACurrentMediaTime()
                let linkmap = try await LinkMap.analyze(path: selectedFile)
                if Task.isCancelled { return }
                let anaEnd = CACurrentMediaTime()
                self.linkmap = linkmap

                let sizeInfo = await AppState.updateOutput(linkmap: linkmap, query: query)
                Logging.info("updated path at \(URL(fileURLWithPath: selectedFile).lastPathComponent): analyze: \(anaEnd - begin)s, output: \(CACurrentMediaTime() - anaEnd)")
                self.sizeInfo = sizeInfo
            }
        }
    }
    private var _loading: (() -> Void)? {
        didSet {
            oldValue?()
            // delay update to avoid flick
            if _loading != nil { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: { self.objectWillChange.send() }) }
            else { objectWillChange.send() }
        }
    }
    public var isLoading: Bool { _loading != nil }
    var tip: (String, Color)?
    struct Query {
        var query: String = ""
    }
    @Published var query = Query()
    func updateQuery() {
        guard let linkmap else { return }
        Logging.debug("update Query")
        loading { [self] in
            let sizeInfo = await AppState.updateOutput(linkmap: linkmap, query: query)
            self.sizeInfo = sizeInfo
        }
    }
    func loading(action: @escaping () async throws -> Void) {
        let task = Task {
            do {
                try await action()
                if Task.isCancelled { return }
                tip = nil
            } catch {
                if Task.isCancelled { return }
                tip = (error.localizedDescription, .red)
            }
            self._loading = nil
        }
        tip = ("loading", .gray)
        self._loading = { task.cancel() }
    }

    // MARK: Result
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

    nonisolated static func updateOutput(linkmap: LinkMap, query: Query) async -> ([Row], String) {
        let objects = linkmap.indexes.values
        var rows: [Row]
        if !query.query.isEmpty {
            rows = objects.compactMap { (o) -> Row? in
                let name = o.name
                guard name.contains(query.query) else { return nil }
                return Row(id: o.path, size: o.total, name: o.name)
            }
        } else {
            rows = objects.map { (o) in
                return Row(id: o.path, size: o.total, name: o.name)
            }
        }
        rows = rows.sorted(key: { -$0.size })
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


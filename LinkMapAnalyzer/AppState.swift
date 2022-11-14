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
        $query.debounce(for: 0.3, scheduler: RunLoop.main).sink { (_) in
            self.updateQuery()
        }.store(in: &bags)
    }
    // MARK: input
    var manualChoose: [String] = []
    var selectedFile: String = "" {
        didSet {
            if selectedFile == oldValue { return }
            manualChoose.insert(selectedFile, at: 0)
            manualChoose = manualChoose.unique()
            self.linkmap = nil // 为空时屏蔽其他的loading
            loading { [self, selectedFile] in
                let begin = CACurrentMediaTime()
                let linkmap = try await LinkMap.analyze(path: selectedFile)
                if Task.isCancelled { return }
                self.linkmap = linkmap
                Logging.info("updated path at \(URL(fileURLWithPath: selectedFile).lastPathComponent): analyze: \(CACurrentMediaTime() - begin)s")

                let sizeInfo = await AppState.updateOutput(linkmap: linkmap, query: query)
                self.sizeInfo = sizeInfo
            }
        }
    }
    @Published private var _loading: (() -> Void)? {
        didSet {
            oldValue?()
            // objectWillChange.send()
        }
    }
    public var isLoading: Bool { _loading != nil }
    var tip: (String, Color)?
    struct Query {
        var query: String = ""
        enum Category: String, CaseIterable, Identifiable {
            case library, object, symbol
            var id: Self { self  }
        }
        var category: Category = .library
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
    typealias SizeInfo = (rows: [Row], summary: String, updateTime: CFTimeInterval)
    var sizeInfo: SizeInfo? // row, summary
    struct Row: Identifiable {
        // var id = UUID() // avoid diff and animation crash
        var id: String
        var size: Int
        var name: String
        var sizeStr: String {
            AppState.format(num: size)
        }
    }

    nonisolated static func updateOutput(linkmap: LinkMap, query: Query) async -> SizeInfo {
        let begin = CACurrentMediaTime()
        defer { Logging.info("update output in \(CACurrentMediaTime() - begin)s") }
        let objects = linkmap.indexes.values
        var rows: [Row]
        switch query.category {
        case .object:
            rows = objects.map { (o) in
                return Row(id: o.path, size: o.total, name: o.name)
            }
        case .symbol:
            rows = objects.flatMap { $0.symbols.values }
                .map { Row(id: $0.name, size: $0.size, name: $0.name) }
        case .library:
            rows = Dictionary(grouping: objects, by: { $0.libraryName }).map { k, a in
                return Row(id: k, size: a.map(\.total).reduce(0,+), name: k)
            }
        }
        if !query.query.isEmpty {
            rows.removeAll { !$0.name.contains(query.query) }
        }
        rows = rows.sorted(key: { -$0.size })
        let total = rows.map(\.size).reduce(0, +)
        return (rows, "总大小：\(AppState.format(num: total))", begin)
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


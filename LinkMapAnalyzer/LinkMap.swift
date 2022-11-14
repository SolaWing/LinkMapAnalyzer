//
//  LinkMap.swift
//  LinkMapAnalyzer
//
//  Created by SolaWing on 2022/11/12.
//

import Foundation
import Darwin

struct LinkMap {
    let path: String
    let indexes: [Int: ObjectFile]
    enum Err: Error {
    case invalidPath
    }
    public static func availableLinkMapFiles() -> [String] {
        do {
            let fm = FileManager.default
            let root = try fm.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor:nil, create:false).appendingPathComponent("Developer/Xcode/DerivedData/").path
            let rootDir = try fm.contentsOfDirectory(atPath: root)
            let v = rootDir.flatMap { (file: String) in
                if let index = file.lastIndex(of: "-") {
                    let name = file[..<index]
                    return fm.glob([root, file, "Build/Intermediates*/\(name).build/*/\(name).build/\(name)-LinkMap*.txt"].joined(separator: "/"))
                }
                return []
            }.sorted(key: { -((try? fm.attributesOfItem(atPath: $0)[FileAttributeKey.modificationDate]) as? Date ?? Date.distantPast).timeIntervalSinceReferenceDate })
            return v
        } catch {
            print("[ERROR] \(error)")
            return []
        }
    }
    public static func analyze(path: String) async throws -> LinkMap {
        var indexes: [Int: ObjectFile] = [:]
        enum Section {
        case none, obj, sec, sym, dead
        }
        guard
            let data = FileManager.default.contents(atPath: path)
            // may include none-utf8 char
            ,let contents = String(data: data, encoding: .macOSRoman)
        else { throw Err.invalidPath }
        // let contents = String(data: data, encoding: .utf8) ??
        //     String.init(unsafeUninitializedCapacity: data.count, initializingUTF8With: {
        //                     _ = $0.initialize(from: data)
        //                     return data.count
        //                 })

        var section = Section.none
        contents.enumerateLines { (line, stop) in
            if Task.isCancelled { stop = true; return }
            if line.first == "#" { // read section
                if line.starts(with: "# Object files:") {
                  section = .obj
                } else if line.starts(with: "# Sections:") {
                  section = .sec
                } else if line.starts(with: "# Symbols:") {
                  section = .sym
                } else if line.starts(with: "# Dead Stripped Symbols:") {
                  section = .dead
                  stop = true // TODO: not implement
                }
                return
            }
            switch section {
            case .obj: ObjSection()
            case .sym: SymSection()
            default: break
            }
            func ObjSection() {
                guard let (index, file) = extractIndexAndPath(line) else {
                    Logging.debug("section extract fail \(line)")
                    return
                }
                indexes[index] = ObjectFile(index: index, path: file, symbols: [:])
            }
            func SymSection() {
                let parts = line.split(separator: "\t", maxSplits: 2)
                func log() {
                    if !line.isEmpty { // obj section end with a empty line
                        Logging.debug("obj extract fail \(line)")
                    }
                }
                guard parts.count == 3 else { log() ;return }
                guard let (index, sym) = extractIndexAndPath((parts[2])) else { log() ;return }
                guard let start = Int.from(parts[0]), let size = Int.from(parts[1]) else { log() ;return }
                indexes[index]?.symbols[sym] = .init(start: start, size: size, name: sym)
            }
        }
        try Task.checkCancellation()
        if section == .none { throw Err.invalidPath }
        return .init(path: path, indexes: indexes)
    }
    struct ObjectFile {
        var index: Int
        var path: String
        var symbols: [String: Symbol]

        var total: Int { symbols.values.map(\.size).reduce(0, +) }
        var name: String { URL(fileURLWithPath: path).lastPathComponent }
    }
    struct Symbol {
        var start: Int
        var size: Int
        var name: String
    }
    static func extractIndexAndPath<T: StringProtocol>(_ line: T) -> (Int, String)? {
        guard
            line.first == "[",
            let sep = line.firstIndex(of: "]"),
            let index = Int.from(line[line.index(offset: 1)..<sep]),
            case let contents = line.suffix(from: line.index(sep, offsetBy: 2))
        else { return nil }
        return (index, String(contents))
    }
}

extension StringProtocol {
    func index(offset: Int) -> Index {
        return self.index(self.startIndex, offsetBy: offset)
    }
}

extension Int {
    static func from<T: StringProtocol>(_ from: T) -> Int? {
        return from.withCString { (p) -> Int? in
            var end: UnsafeMutablePointer<CChar>?
            let v = strtoull(p, &end, 0)
            if Int(bitPattern: p) == Int(bitPattern: end) { return nil }
            return Int(truncatingIfNeeded: v)
        }
    }
}

extension FileManager {
    func glob(_ pattern: String) -> [String] {
        var g = glob_t()
        Darwin.glob(pattern, 0, nil, &g)
        defer { Darwin.globfree(&g) }
        return (0..<g.gl_pathc).map { i in
            let v = g.gl_pathv[i]
            return String(cString: v!)
        }
    }
}

extension Sequence {
    func sorted<T: Comparable>(key: (Element) -> T) -> [Element] {
        return self.map { (key($0), $0) }.sorted(by: { $0.0 < $1.0 })
            .map { $0.1 }
    }
    func unique() -> [Element] where Element: Hashable {
        var s = Set<Element>()
        return filter { s.insert($0).inserted }
    }
}

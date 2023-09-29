//
//  ContentView.swift
//  LinkMapAnalyzer
//
//  Created by SolaWing on 2022/11/11.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject var app = AppState()
    // TODO: output copy
    var body: some View {
        let _ = Logging.debug("load ContentView")
        VStack(spacing: 8) {
            HStack {
                Picker("选择LinkMap文件。你也可以拖放文件:", selection: $app.selectedFile) {
                    if app.manualChoose.count > 0 {
                        Section("recent choose") {
                            ForEach(app.manualChoose, id: \.self) { Text($0) }
                        }
                    }
                    Section("available") {
                        ForEach(LinkMap.availableLinkMapFiles(), id: \.self) { Text($0) }
                    }
                }
                Button("Refresh") { app.updateLinkMap() }
            }
            TextField("Query: ", text: $app.query.query)
            HStack {
                Picker("Category By: ", selection: $app.query.category) {
                    ForEach(AppState.Query.Category.allCases) {
                        Text($0.rawValue.capitalized).tag($0)
                    }
                }.pickerStyle(.radioGroup).horizontalRadioGroupLayout()
                if app.isLoading { ProgressView().scaleEffect(0.5) }
                if let tip = app.tip { Text(tip.0).foregroundColor(tip.1) }
                Spacer()
            }.frame(height: 22)
            if let sizeInfo = app.sizeInfo {
                SizeTable(data: sizeInfo).equatable().frame(minHeight: 240)
                Spacer()
                Text(sizeInfo.summary)
            } else {
                Text("""
                     Usage：
                     1. XCode -> Project -> Build Settings -> Write Link Map File = yes
                     2. Build With Release Configuration
                     3. Choose LinkMap and start analyze
                     """)
                // .padding(.top, 8)
                Spacer()
            }
        }
        .padding()
        .frame(minWidth: 480, minHeight: 360)
        .onDrop(of: [.fileURL], isTargeted: nil) { (providers) -> Bool in
            providers[0].loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { (data, error) in
                if let data, let path = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        app.selectedFile = path.path
                    }
                }
            }
            // providers[0].loadObject(ofClass: URL.self) { (read, error) in
            // }
            return false
        }
    }
}
struct SizeTable: View, Equatable {
    static func == (lhs: SizeTable, rhs: SizeTable) -> Bool {
        // Logging.debug("SizeTable: \(lhs.data.1) == \(rhs.data.1)")
        return lhs.data.updateTime == rhs.data.updateTime
    }

    var data: AppState.SizeInfo
    var body: some View {
        let _ = Logging.debug("load SizeTable")
        if data.category == .symbol {
            Table(data.rows) {
                TableColumn("Size", value: \.sizeStr).width(max: 100)
                TableColumn("Name") { Text($0.name).truncationMode(.head) }
                TableColumn("Lib") { Text($0.lib ?? "").truncationMode(.head) }
            }.id(data.updateTime) // disable reuse table and force reload to avoid diff bug
        } else {
            Table(data.rows) {
                TableColumn("Size", value: \.sizeStr).width(max: 100)
                TableColumn("Name") { Text($0.name).truncationMode(.head) }
            }.id(data.updateTime) // disable reuse table and force reload to avoid diff bug
        }
    }
}

struct Wrapper<T: Hashable>: Identifiable {
    var id: T { base }
    var base: T
    init(_ base: T) { self.base = base }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

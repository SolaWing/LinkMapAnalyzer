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
    var body: some View {
        let _ = Logging.debug("load ContentView")
        VStack {
            Picker("选择LinkMap文件。你也可以拖放文件", selection: $app.selectedFile) {
                ForEach(app.fileToBeSelect, id: \.self) { (path) in
                    Text(path)
                }
            }
            HStack {
                if app.loading != nil { ProgressView().scaleEffect(0.5) }
                if let tip = app.tip { Text(tip.0).foregroundColor(tip.1) }
            }
            if let sizeInfo = app.sizeInfo {
                let _ = Logging.debug("load sizeInfo")
                Table(sizeInfo.0) {
                    TableColumn("Size", value: \.sizeStr)
                    TableColumn("Name") {
                        Text($0.name).truncationMode(.head)
                    }
                }.id(sizeInfo.1) // disable reuse table and force reload to avoid diff bug
                .frame(minHeight: 240)
                .padding(.top, 8)
                Text(sizeInfo.1)
            } else {
                Text("""
                     使用方式：
                     1. XCode -> Project -> Build Settings -> Write Link Map File = yes
                     2. choose LinkMap and start analyze
                     """)
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

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: DocumentStore
    @State private var selectedTab = 0
    @State private var requestedFile: TextFile?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                LibraryView(requestedFile: $requestedFile)
            }
            .tabItem {
                Label("文件", systemImage: "doc.text")
            }
            .tag(0)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }
            .tag(1)
        }
        .tint(.indigo)
        .onOpenURL(perform: openExternalFile)
    }

    private func openExternalFile(_ url: URL) {
        do {
            let file = try store.importFile(from: url)
            selectedTab = 0
            requestedFile = file
        } catch {
            store.report(error)
        }
    }
}

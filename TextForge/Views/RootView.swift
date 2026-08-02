import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: DocumentStore
    @AppStorage("lastSeenChangelogVersion") private var lastSeenChangelogVersion = ""
    @State private var selectedTab = 0
    @State private var requestedFile: TextFile?
    @State private var isWhatsNewPresented = false

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
        .sheet(isPresented: $isWhatsNewPresented) {
            WhatsNewView(version: currentVersion)
        }
        .task {
            presentWhatsNewIfNeeded()
        }
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

    private var currentVersion: String {
        if let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String {
            return version
        }
        return "1.1.3"
    }

    private func presentWhatsNewIfNeeded() {
        guard lastSeenChangelogVersion != currentVersion else { return }
        lastSeenChangelogVersion = currentVersion
        isWhatsNewPresented = true
    }
}

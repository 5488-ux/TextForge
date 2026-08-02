import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: DocumentStore
    @AppStorage("lastSeenChangelogVersion") private var lastSeenChangelogVersion = ""
    @State private var selectedTab = 0
    @State private var requestedFile: TextFile?
    @State private var isWhatsNewPresented = false

    var body: some View {
        ZStack {
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

            if let progress = store.importProgress {
                ImportProgressOverlay(progress: progress)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(10)
            }
        }
        .tint(.indigo)
        .preferredColorScheme(.light)
        .onOpenURL(perform: openExternalFile)
        .sheet(isPresented: $isWhatsNewPresented) {
            WhatsNewView(version: currentVersion)
        }
        .task {
            presentWhatsNewIfNeeded()
        }
    }

    private func openExternalFile(_ url: URL) {
        Task {
            do {
                let importedFiles = try await store.importFiles(from: [url])
                selectedTab = 0
                requestedFile = importedFiles.last
            } catch {
                store.report(error)
            }
        }
    }

    private var currentVersion: String {
        if let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String {
            return version
        }
        return "1.1.4"
    }

    private func presentWhatsNewIfNeeded() {
        guard lastSeenChangelogVersion != currentVersion else { return }
        lastSeenChangelogVersion = currentVersion
        isWhatsNewPresented = true
    }
}

private struct ImportProgressOverlay: View {
    let progress: DocumentImportProgress

    var body: some View {
        ZStack {
            Color.black.opacity(0.10)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(TextForgePalette.blue.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: "doc.badge.arrow.up.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(TextForgePalette.blue)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("正在导入")
                            .font(.headline)
                        Text(progress.fileName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(progress.countText)
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(TextForgePalette.blue)
                }

                ProgressView(value: progress.overallFraction)
                    .tint(TextForgePalette.blue)
                    .scaleEffect(x: 1, y: 1.3, anchor: .center)

                HStack {
                    Text(progress.phase)
                    Spacer()
                    Text("\(Int(progress.overallFraction * 100))%")
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 340)
            .textForgeGlassCard()
            .padding(.horizontal, 24)
        }
        .allowsHitTesting(true)
    }
}

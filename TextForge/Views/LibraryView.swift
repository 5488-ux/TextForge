import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: DocumentStore
    @Binding var requestedFile: TextFile?
    @State private var query = ""
    @State private var isImporterPresented = false
    @State private var isNewFilePresented = false
    @State private var selectedFile: TextFile?
    @State private var pendingImportURLs: [URL] = []

    private var filteredFiles: [TextFile] {
        guard !query.isEmpty else { return store.files }
        return store.files.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ZStack {
            TextForgeBackground()

            ScrollView {
                LazyVStack(spacing: 16) {
                    header
                    searchField
                    quickActions
                    filesSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable { store.reload() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: TextFile.self) { file in
            EditorView(file: file)
        }
        .sheet(isPresented: $isImporterPresented, onDismiss: importPendingFiles) {
            TextDocumentPicker(isPresented: $isImporterPresented) { urls in
                pendingImportURLs = urls
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isNewFilePresented) {
            NewFileView { file in
                isNewFilePresented = false
                selectedFile = file
            }
        }
        .navigationDestination(item: $selectedFile) { file in
            EditorView(file: file)
        }
        .alert("出错了", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("知道了") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "未知错误")
        }
        .onAppear {
            store.reload()
            openRequestedFileIfNeeded()
        }
        .onChange(of: requestedFile) { _, file in
            if file != nil { openRequestedFileIfNeeded() }
        }
    }

    private var header: some View {
        HStack(spacing: 13) {
            TextForgeLogo()

            VStack(alignment: .leading, spacing: 3) {
                Text("TextForge")
                    .font(.system(size: 27, weight: .heavy, design: .rounded))
                Text("轻快、漂亮、什么文本都能改")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            TextForgeCircleButton(
                systemImage: "square.and.arrow.down.fill",
                accessibilityLabel: "导入文件"
            ) {
                isImporterPresented = true
            }

            TextForgeCircleButton(
                systemImage: "plus",
                accessibilityLabel: "新建文件"
            ) {
                isNewFilePresented = true
            }
        }
        .padding(.vertical, 8)
    }

    private func openRequestedFileIfNeeded() {
        guard let file = requestedFile else { return }
        selectedFile = file
        requestedFile = nil
    }

    private func importPendingFiles() {
        guard !pendingImportURLs.isEmpty else { return }
        let urls = pendingImportURLs
        pendingImportURLs = []

        do {
            var imported: TextFile?
            for url in urls {
                imported = try store.importFile(from: url)
            }
            selectedFile = imported
        } catch {
            store.report(error)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(TextForgePalette.blue)

            TextField("搜索文件", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .textForgeInput()
        .shadow(color: TextForgePalette.blue.opacity(0.06), radius: 14, y: 8)
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 15) {
            TextForgeSectionTitle(
                title: "开始创作",
                subtitle: "导入已有文档，或者从一张白纸开始"
            )

            HStack(spacing: 12) {
                actionButton(
                    title: "导入文件",
                    subtitle: "SRT、TXT、MD…",
                    icon: "square.and.arrow.down.fill",
                    colors: [TextForgePalette.blue, TextForgePalette.cyan]
                ) {
                    isImporterPresented = true
                }

                actionButton(
                    title: "新建文稿",
                    subtitle: "扩展名随便定",
                    icon: "plus.rectangle.on.folder.fill",
                    colors: [TextForgePalette.violet, TextForgePalette.indigo]
                ) {
                    isNewFilePresented = true
                }
            }
        }
        .textForgeGlassCard()
    }

    private var filesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextForgeSectionTitle(
                title: query.isEmpty ? "最近文件" : "搜索结果",
                subtitle: query.isEmpty ? "所有修改都会自动保存" : "匹配“\(query)”的文件",
                trailingText: "\(filteredFiles.count)"
            )

            if filteredFiles.isEmpty {
                emptyState
            } else {
                ForEach(filteredFiles) { file in
                    NavigationLink(value: file) {
                        FileCard(file: file)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        ShareLink(item: file.url) {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                        Button(role: .destructive) {
                            do { try store.delete(file) } catch { store.report(error) }
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .textForgeGlassCard()
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(TextForgePalette.blue.opacity(0.09))
                    .frame(width: 72, height: 72)
                Image(systemName: query.isEmpty ? "doc.badge.plus" : "magnifyingglass")
                    .font(.system(size: 29, weight: .semibold))
                    .foregroundStyle(TextForgePalette.blue)
            }
            Text(query.isEmpty ? "这里还很空" : "一个都没搜到")
                .font(.headline)
            Text(query.isEmpty ? "导入文件或新建文稿，别让它继续吃灰。" : "换个关键词试试。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func actionButton(
        title: String,
        subtitle: String,
        icon: String,
        colors: [Color],
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.78), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct FileCard: View {
    let file: TextFile

    private var accent: Color {
        switch file.fileExtension {
        case "md", "markdown": return TextForgePalette.violet
        case "srt": return .orange
        case "json", "yaml", "yml": return .green
        default: return TextForgePalette.blue
        }
    }

    private var icon: String {
        switch file.fileExtension {
        case "md", "markdown": return "doc.richtext.fill"
        case "srt": return "captions.bubble.fill"
        case "json", "yaml", "yml": return "curlybraces.square.fill"
        default: return "doc.text.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(0.12))
                    .frame(width: 50, height: 50)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(file.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(file.typeLabel)
                    Text("·")
                    Text(ByteCountFormatter.string(fromByteCount: file.byteCount, countStyle: .file))
                    Text("·")
                    Text(file.modifiedAt.formatted(date: .abbreviated, time: .omitted))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 6)

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(.white.opacity(0.75), lineWidth: 1)
        }
    }
}

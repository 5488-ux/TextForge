import SwiftUI

struct EditorView: View {
    enum MarkdownMode: String, CaseIterable, Identifiable {
        case edit = "修改"
        case preview = "预览"
        var id: String { rawValue }
    }

    @EnvironmentObject private var store: DocumentStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var file: TextFile
    @State private var text = ""
    @State private var mode: MarkdownMode = .edit
    @State private var isLoaded = false
    @State private var isDirty = false
    @State private var renameText = ""
    @State private var isRenamePresented = false
    @State private var saveTask: Task<Void, Never>?

    init(file: TextFile) {
        _file = State(initialValue: file)
    }

    var body: some View {
        VStack(spacing: 0) {
            if file.isMarkdown {
                Picker("Markdown 模式", selection: $mode) {
                    ForEach(MarkdownMode.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 10)
            }

            Group {
                if file.isMarkdown && mode == .preview {
                    MarkdownPreview(text: text)
                } else {
                    TextEditor(text: $text)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 10)
                        .background(Color(uiColor: .systemBackground))
                }
            }

            HStack {
                Label("\(text.count) 字符", systemImage: "textformat.size")
                Spacer()
                Text(isDirty ? "正在保存…" : "已保存")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(item: file.url) {
                    Label("分享", systemImage: "square.and.arrow.up")
                }
                Menu {
                    Button {
                        renameText = file.name
                        isRenamePresented = true
                    } label: {
                        Label("重命名", systemImage: "pencil")
                    }
                    Button { saveNow() } label: {
                        Label("立即保存", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Label("更多", systemImage: "ellipsis.circle")
                }
            }
        }
        .task { load() }
        .onChange(of: text) { _, _ in
            guard isLoaded else { return }
            isDirty = true
            scheduleSave()
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue != .active { saveNow() }
        }
        .onDisappear { saveNow() }
        .alert("重命名", isPresented: $isRenamePresented) {
            TextField("完整文件名", text: $renameText)
            Button("取消", role: .cancel) {}
            Button("确定") { rename() }
        } message: {
            Text("扩展名也能一起改，别手滑删没了。")
        }
    }

    private func load() {
        guard !isLoaded else { return }
        do {
            text = try store.read(file)
            isLoaded = true
        } catch {
            store.report(error)
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            saveNow()
        }
    }

    private func saveNow() {
        guard isLoaded, isDirty else { return }
        saveTask?.cancel()
        do {
            try store.save(text, to: file)
            isDirty = false
        } catch {
            store.report(error)
        }
    }

    private func rename() {
        saveNow()
        do {
            file = try store.rename(file, to: renameText)
        } catch {
            store.report(error)
        }
    }
}

private struct MarkdownPreview: View {
    let text: String

    var body: some View {
        ScrollView {
            Group {
                if let attributed = try? AttributedString(
                    markdown: text,
                    options: .init(interpretedSyntax: .full)
                ) {
                    Text(attributed)
                } else {
                    Text(text)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .padding(18)
        }
        .background(Color(uiColor: .secondarySystemBackground))
    }
}

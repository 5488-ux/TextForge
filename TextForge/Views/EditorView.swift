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
        ZStack {
            TextForgeBackground()

            VStack(spacing: 12) {
                if file.isMarkdown {
                    markdownSwitcher
                }

                editorSurface
                statusBar
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(item: file.url) {
                    Image(systemName: "square.and.arrow.up")
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
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task { await load() }
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

    private var markdownSwitcher: some View {
        HStack(spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "doc.richtext.fill")
                    .foregroundStyle(TextForgePalette.violet)
                Text("Markdown")
                    .font(.subheadline.bold())
            }

            Spacer()

            Picker("Markdown 模式", selection: $mode) {
                ForEach(MarkdownMode.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 180)
        }
        .textForgeGlassCard(padding: 12, cornerRadius: 20)
    }

    private var editorSurface: some View {
        Group {
            if !isLoaded {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(TextForgePalette.blue)
                    Text("正在加载文稿…")
                        .font(.subheadline.bold())
                    Text("大文件放到后台读取，界面不会再冻住。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if file.isMarkdown && mode == .preview {
                MarkdownPreview(text: text)
            } else {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(emptyPrompt)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 17)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $text)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(9)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.86), lineWidth: 1)
        }
        .shadow(color: TextForgePalette.indigo.opacity(0.08), radius: 22, y: 10)
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            Label("\(text.count) 字符", systemImage: "textformat.size")

            if !file.fileExtension.isEmpty {
                Text(file.typeLabel)
                    .font(.caption2.bold())
                    .foregroundStyle(TextForgePalette.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(TextForgePalette.blue.opacity(0.10), in: Capsule())
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(isDirty ? Color.orange : Color.green)
                    .frame(width: 7, height: 7)
                Text(isDirty ? "正在保存" : "已保存")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .textForgeGlassCard(padding: 10, cornerRadius: 18)
    }

    private var emptyPrompt: String {
        switch file.fileExtension {
        case "md", "markdown": "# 从这里开始写 Markdown…"
        case "srt": "1\n00:00:00,000 --> 00:00:03,000\n从这里开始写字幕…"
        default: "从这里开始输入…"
        }
    }

    private func load() async {
        guard !isLoaded else { return }
        do {
            text = try await store.readAsync(file)
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

    @State private var blocks: [MarkdownBlock] = []
    @State private var isRendering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                if text.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.richtext")
                            .font(.system(size: 34))
                            .foregroundStyle(TextForgePalette.violet)
                        Text("写点 Markdown，再来看预览。")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else if blocks.isEmpty && isRendering {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(TextForgePalette.violet)
                        Text("正在渲染 Markdown…")
                            .font(.subheadline.bold())
                        Text("解析放在后台，长文档也不会卡住界面。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(blocks) { block in
                            MarkdownBlockView(block: block)
                        }
                    }
                    .frame(maxWidth: 760, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .padding(20)
                }
            }
            .textSelection(.enabled)

            if isRendering && !blocks.isEmpty {
                ProgressView()
                    .tint(TextForgePalette.violet)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
                    .padding(12)
            }
        }
        .task(id: text) {
            await renderMarkdown()
        }
    }

    private func renderMarkdown() async {
        if text.isEmpty {
            blocks = []
            isRendering = false
            return
        }

        isRendering = true
        try? await Task.sleep(for: .milliseconds(100))
        guard !Task.isCancelled else { return }

        let source = text
        let parsed = await Task.detached(priority: .userInitiated) {
            MarkdownRenderer.parse(source)
        }.value

        guard !Task.isCancelled else { return }
        blocks = parsed
        isRendering = false
    }
}

private struct MarkdownBlockView: View {
    let block: MarkdownBlock

    var body: some View {
        switch block.kind {
        case .heading(let level):
            Text(block.attributed)
                .font(headingFont(level))
                .fontWeight(level <= 2 ? .heavy : .bold)
                .padding(.top, level == 1 ? 8 : 3)

        case .paragraph:
            Text(block.attributed)
                .font(.body)
                .lineSpacing(4)

        case .bullet:
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Circle()
                    .fill(TextForgePalette.violet)
                    .frame(width: 6, height: 6)
                Text(block.attributed)
                    .font(.body)
                    .lineSpacing(3)
            }
            .padding(.leading, 6)

        case .numbered(let marker):
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(marker)
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(TextForgePalette.blue)
                    .frame(minWidth: 24, alignment: .trailing)
                Text(block.attributed)
                    .font(.body)
                    .lineSpacing(3)
            }

        case .quote:
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(TextForgePalette.violet)
                    .frame(width: 4)
                Text(block.attributed)
                    .font(.body.italic())
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }
            .padding(12)
            .background(TextForgePalette.violet.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

        case .code:
            ScrollView(.horizontal, showsIndicators: false) {
                Text(block.content)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(Color(red: 0.88, green: 0.92, blue: 1.00))
                    .textSelection(.enabled)
                    .padding(14)
            }
            .background(Color(red: 0.10, green: 0.12, blue: 0.20), in: RoundedRectangle(cornerRadius: 14))

        case .separator:
            Divider()
                .padding(.vertical, 6)

        case .spacer:
            Color.clear
                .frame(height: 4)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .largeTitle
        case 2: return .title
        case 3: return .title2
        case 4: return .title3
        default: return .headline
        }
    }
}

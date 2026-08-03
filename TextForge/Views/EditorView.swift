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
    @State private var encoding: DocumentTextEncoding = .utf8
    @State private var lineEnding: DocumentLineEnding = .lf
    @State private var isLargeFile = false
    @State private var allowLargeMarkdownPreview = false
    @State private var isLoaded = false
    @State private var isDirty = false
    @State private var renameText = ""
    @State private var isRenamePresented = false
    @State private var isFindPresented = false
    @State private var isSRTToolsPresented = false
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
        .toolbar { editorToolbar }
        .task { await load() }
        .onChange(of: text) { _, _ in
            guard isLoaded else { return }
            isDirty = true
            if !isLargeFile { scheduleSave() }
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue != .active { saveNow() }
        }
        .onDisappear { saveNow() }
        .sheet(isPresented: $isFindPresented) {
            FindReplaceView(text: $text)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isSRTToolsPresented) {
            SRTToolView(text: $text)
                .presentationDetents([.medium, .large])
        }
        .alert("重命名", isPresented: $isRenamePresented) {
            TextField("完整文件名", text: $renameText)
            Button("取消", role: .cancel) {}
            Button("确定") { rename() }
        } message: {
            Text("扩展名也能一起改，别手滑删没了。")
        }
    }

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                isFindPresented = true
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .disabled(!isLoaded)

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
                .disabled(!isDirty)

                if file.isSubtitle {
                    Button {
                        isSRTToolsPresented = true
                    } label: {
                        Label("SRT 时间轴工具", systemImage: "captions.bubble.fill")
                    }
                }

                Menu("文本编码") {
                    ForEach(DocumentTextEncoding.allCases, id: \.self) { item in
                        Button {
                            encoding = item
                            isDirty = true
                        } label: {
                            if encoding == item {
                                Label(item.rawValue, systemImage: "checkmark")
                            } else {
                                Text(item.rawValue)
                            }
                        }
                    }
                }

                Menu("换行格式") {
                    ForEach(DocumentLineEnding.allCases, id: \.self) { item in
                        Button {
                            lineEnding = item
                            isDirty = true
                        } label: {
                            if lineEnding == item {
                                Label(item.rawValue, systemImage: "checkmark")
                            } else {
                                Text(item.rawValue)
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
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
                loadingView
            } else if file.isMarkdown && mode == .preview {
                markdownPreviewSurface
            } else {
                textEditor
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

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
                .tint(TextForgePalette.blue)
            Text("正在加载文稿…")
                .font(.subheadline.bold())
            Text("文件放到后台读取，界面不会冻住。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var markdownPreviewSurface: some View {
        if isLargeFile && !allowLargeMarkdownPreview {
            VStack(spacing: 14) {
                Image(systemName: "doc.badge.clock")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(TextForgePalette.violet)
                Text("大文件预览已暂停")
                    .font(.headline)
                Text("这个 Markdown 超过 1 MB。直接实时渲染容易卡，点一次再渲染。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                Button("仍然预览") {
                    allowLargeMarkdownPreview = true
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            MarkdownPreview(text: text)
        }
    }

    private var textEditor: some View {
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
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding(9)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 9) {
            Label("\(text.utf16.count) 字符", systemImage: "textformat.size")

            Text(encoding.rawValue)
                .statusBadge(color: TextForgePalette.blue)

            Text(lineEnding.rawValue)
                .statusBadge(color: TextForgePalette.violet)

            if isLargeFile {
                Text("大文件")
                    .statusBadge(color: .orange)
            }

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                Circle()
                    .fill(isDirty ? Color.orange : Color.green)
                    .frame(width: 7, height: 7)
                Text(isLargeFile && isDirty ? "点保存" : (isDirty ? "正在保存" : "已保存"))
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
            let document = try await store.readAsync(file)
            text = document.text
            encoding = document.encoding
            lineEnding = document.lineEnding
            isLargeFile = document.isLargeFile
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
            try store.save(text, to: file, encoding: encoding, lineEnding: lineEnding)
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

private extension View {
    func statusBadge(color: Color) -> some View {
        self
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(color.opacity(0.10), in: Capsule())
    }
}

private struct FindReplaceView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String

    @State private var query = ""
    @State private var replacement = ""
    @State private var isCaseSensitive = false
    @State private var usesRegularExpression = false
    @State private var message = "输入要查找的内容"

    var body: some View {
        NavigationStack {
            Form {
                Section("查找") {
                    TextField("查找内容", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    TextField("替换为", text: $replacement)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    Toggle("区分大小写", isOn: $isCaseSensitive)
                    Toggle("正则表达式", isOn: $usesRegularExpression)
                }

                Section {
                    Text(message)
                        .foregroundStyle(.secondary)

                    Button("统计匹配") { updateMatchCount() }
                    Button("替换下一个") { replaceNext() }
                        .disabled(query.isEmpty)
                    Button("全部替换") { replaceAll() }
                        .disabled(query.isEmpty)
                }
            }
            .navigationTitle("查找与替换")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onChange(of: query) { _, _ in updateMatchCount() }
            .onChange(of: isCaseSensitive) { _, _ in updateMatchCount() }
            .onChange(of: usesRegularExpression) { _, _ in updateMatchCount() }
        }
    }

    private func regularExpression() throws -> NSRegularExpression {
        let pattern = usesRegularExpression ? query : NSRegularExpression.escapedPattern(for: query)
        let options: NSRegularExpression.Options = isCaseSensitive ? [] : [.caseInsensitive]
        return try NSRegularExpression(pattern: pattern, options: options)
    }

    private func updateMatchCount() {
        guard !query.isEmpty else {
            message = "输入要查找的内容"
            return
        }
        do {
            let regex = try regularExpression()
            let range = NSRange(text.startIndex..., in: text)
            let count = regex.numberOfMatches(in: text, range: range)
            message = "找到 \(count) 处匹配"
        } catch {
            message = "正则写错了：\(error.localizedDescription)"
        }
    }

    private func replaceNext() {
        do {
            let regex = try regularExpression()
            let range = NSRange(text.startIndex..., in: text)
            guard let match = regex.firstMatch(in: text, range: range),
                  let swiftRange = Range(match.range, in: text) else {
                message = "没找到匹配内容"
                return
            }
            let value = usesRegularExpression
                ? regex.replacementString(for: match, in: text, offset: 0, template: replacement)
                : replacement
            text.replaceSubrange(swiftRange, with: value)
            updateMatchCount()
        } catch {
            message = "正则写错了：\(error.localizedDescription)"
        }
    }

    private func replaceAll() {
        do {
            let regex = try regularExpression()
            let range = NSRange(text.startIndex..., in: text)
            let count = regex.numberOfMatches(in: text, range: range)
            let template = usesRegularExpression
                ? replacement
                : NSRegularExpression.escapedTemplate(for: replacement)
            text = regex.stringByReplacingMatches(
                in: text,
                range: range,
                withTemplate: template
            )
            message = "已替换 \(count) 处"
        } catch {
            message = "正则写错了：\(error.localizedDescription)"
        }
    }
}

private struct SRTToolView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String

    @State private var shiftSeconds = "1.0"
    @State private var inspection = SRTInspection(cueCount: 0, invalidTimecodes: 0, overlaps: 0, emptyCues: 0)

    var body: some View {
        NavigationStack {
            Form {
                Section("时间轴检查") {
                    Text(inspection.summary)
                    Button("重新检查") { inspect() }
                }

                Section("批量修复") {
                    Button("重新连续编号") {
                        text = SRTTools.renumber(text)
                        inspect()
                    }

                    TextField("偏移秒数，例如 1.5", text: $shiftSeconds)
                        .keyboardType(.decimalPad)

                    HStack {
                        Button("整体提前") { shift(direction: -1) }
                        Spacer()
                        Button("整体延后") { shift(direction: 1) }
                    }
                }
            }
            .navigationTitle("SRT 工具")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear { inspect() }
        }
    }

    private func inspect() {
        inspection = SRTTools.inspect(text)
    }

    private func shift(direction: Int64) {
        let normalized = shiftSeconds.replacingOccurrences(of: ",", with: ".")
        guard let seconds = Double(normalized) else { return }
        let milliseconds = Int64((seconds * 1_000).rounded()) * direction
        text = SRTTools.shifted(text, milliseconds: milliseconds)
        inspect()
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
        .task(id: text) { await renderMarkdown() }
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

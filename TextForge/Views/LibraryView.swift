import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var store: DocumentStore
    @State private var query = ""
    @State private var isImporterPresented = false
    @State private var isNewFilePresented = false
    @State private var selectedFile: TextFile?

    private var filteredFiles: [TextFile] {
        guard !query.isEmpty else { return store.files }
        return store.files.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        Group {
            if filteredFiles.isEmpty {
                ContentUnavailableView {
                    Label(query.isEmpty ? "还没有文件" : "没搜到", systemImage: "doc.badge.plus")
                } description: {
                    Text(query.isEmpty ? "导入一个文本文件，或者新建一个。" : "换个关键词，别和文件名较劲。")
                } actions: {
                    if query.isEmpty {
                        Button("新建文件") { isNewFilePresented = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                List {
                    ForEach(filteredFiles) { file in
                        NavigationLink(value: file) {
                            FileRow(file: file)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                do { try store.delete(file) } catch { store.report(error) }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { store.reload() }
            }
        }
        .navigationTitle("TextForge")
        .navigationDestination(for: TextFile.self) { file in
            EditorView(file: file)
        }
        .searchable(text: $query, prompt: "搜索文件")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isImporterPresented = true
                } label: {
                    Label("导入", systemImage: "square.and.arrow.down")
                }

                Button {
                    isNewFilePresented = true
                } label: {
                    Label("新建", systemImage: "plus")
                }
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            do {
                let urls = try result.get()
                var imported: TextFile?
                for url in urls {
                    imported = try store.importFile(from: url)
                }
                selectedFile = imported
            } catch {
                store.report(error)
            }
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
        .onAppear { store.reload() }
    }
}

private struct FileRow: View {
    let file: TextFile

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(file.isMarkdown ? Color.indigo.gradient : Color.teal.gradient)
                    .frame(width: 44, height: 52)
                Text(file.typeLabel.prefix(4))
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(file.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(file.modifiedAt.formatted(date: .abbreviated, time: .shortened)) · \(ByteCountFormatter.string(fromByteCount: file.byteCount, countStyle: .file))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

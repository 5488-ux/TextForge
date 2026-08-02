import SwiftUI

struct NewFileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DocumentStore
    @State private var name = "未命名"
    @State private var fileExtension = "txt"

    let onCreated: (TextFile) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("文件") {
                    TextField("文件名", text: $name)
                        .textInputAutocapitalization(.never)
                    TextField("扩展名，例如 srt、md、txt", text: $fileExtension)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("常用格式") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(["txt", "md", "srt", "json", "csv", "yaml", "swift"], id: \.self) { item in
                                Button(item.uppercased()) { fileExtension = item }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                Section {
                    Text("最终文件名：\(previewName)")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("新建文件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") { create() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var previewName: String {
        let ext = fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        return ext.isEmpty ? name : "\(name).\(ext)"
    }

    private func create() {
        do {
            let file = try store.createFile(name: name, extension: fileExtension)
            onCreated(file)
        } catch {
            store.report(error)
        }
    }
}

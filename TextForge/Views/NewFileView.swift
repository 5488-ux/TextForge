import SwiftUI

struct NewFileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DocumentStore
    @State private var name = "未命名"
    @State private var fileExtension = "txt"

    let onCreated: (TextFile) -> Void

    private let commonExtensions = ["txt", "md", "srt", "json", "csv", "yaml", "swift"]

    var body: some View {
        NavigationStack {
            ZStack {
                TextForgeBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        hero
                        fileCard
                        formatCard
                        createButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("新建文稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private var hero: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [TextForgePalette.violet, TextForgePalette.indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 58, height: 58)
                Image(systemName: "plus.rectangle.on.folder.fill")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("一张新的白纸")
                    .font(.title3.bold())
                Text("名称和格式都由你决定")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .textForgeGlassCard()
    }

    private var fileCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            TextForgeSectionTitle(
                title: "文件信息",
                subtitle: "扩展名可以是任何文本格式"
            )

            VStack(alignment: .leading, spacing: 7) {
                Text("文件名")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                TextField("例如：旅行计划", text: $name)
                    .textInputAutocapitalization(.never)
                    .textForgeInput()
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("扩展名")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                HStack(spacing: 9) {
                    Text(".")
                        .font(.title2.bold())
                        .foregroundStyle(TextForgePalette.blue)
                    TextField("txt", text: $fileExtension)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .textForgeInput()
            }

            HStack {
                Image(systemName: "doc.fill")
                    .foregroundStyle(TextForgePalette.blue)
                Text(previewName)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Spacer()
                Text("最终名称")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(TextForgePalette.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .textForgeGlassCard()
    }

    private var formatCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextForgeSectionTitle(
                title: "常用格式",
                subtitle: "点一下，少敲几个字"
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 9)], spacing: 9) {
                ForEach(commonExtensions, id: \.self) { item in
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) {
                            fileExtension = item
                        }
                    } label: {
                        Text(item.uppercased())
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .foregroundStyle(fileExtension.lowercased() == item ? .white : .primary)
                            .background(
                                fileExtension.lowercased() == item
                                    ? AnyShapeStyle(LinearGradient(
                                        colors: [TextForgePalette.blue, TextForgePalette.indigo],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    : AnyShapeStyle(.white.opacity(0.58)),
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .textForgeGlassCard()
    }

    private var createButton: some View {
        Button(action: create) {
            Label("创建并开始编辑", systemImage: "sparkles")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(
                        colors: [TextForgePalette.blue, TextForgePalette.indigo],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .shadow(color: TextForgePalette.blue.opacity(0.28), radius: 18, y: 9)
        }
        .buttonStyle(.plain)
        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.52 : 1)
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

import SwiftUI

struct SettingsView: View {
    private let repositoryURL = URL(string: "https://github.com/5488-ux/TextForge")!

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(Color.indigo.gradient, in: RoundedRectangle(cornerRadius: 16))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TextForge").font(.title3.bold())
                        Text("版本 1.0.0 · 原生 SwiftUI")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .adaptiveGlass()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("目前功能") {
                FeatureRow(icon: "square.and.arrow.down", title: "多格式导入", detail: "SRT、TXT、Markdown、代码、配置与更多文本格式")
                FeatureRow(icon: "plus.square", title: "自定义新建", detail: "文件名和扩展名都由你决定")
                FeatureRow(icon: "pencil.and.outline", title: "编辑与自动保存", detail: "UTF 文本编辑、重命名、分享和删除")
                FeatureRow(icon: "doc.richtext", title: "Markdown 双模式", detail: "随时切换修改和预览，支持 * 等 Markdown 标记")
                FeatureRow(icon: "magnifyingglass", title: "文件管理", detail: "搜索、排序、类型、体积和修改时间")
            }

            Section("更新日志") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1.0.0 · 2026-08-02").font(.headline)
                    Text("首个版本：文件导入、新建、编辑、Markdown 预览、自动保存、分享与 iOS 26 视觉适配。")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("项目") {
                Link(destination: repositoryURL) {
                    Label("GitHub 仓库", systemImage: "link")
                }
            }
        }
        .navigationTitle("设置")
    }
}

private extension View {
    @ViewBuilder
    func adaptiveGlass() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect()
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(.indigo)
        }
    }
}

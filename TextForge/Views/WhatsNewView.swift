import SwiftUI

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss

    let version: String

    var body: some View {
        NavigationStack {
            ZStack {
                TextForgeBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        hero
                        highlights
                        continueButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("关闭")
                }
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 15) {
            TextForgeLogo(size: 76)

            VStack(spacing: 6) {
                Text("TextForge 更新了")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                Text("版本 \(version)")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(TextForgePalette.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(TextForgePalette.blue.opacity(0.10), in: Capsule())
            }

            Text("这页只在每个新版本第一次启动时出现，不会天天蹦出来烦你。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .textForgeGlassCard()
    }

    private var highlights: some View {
        VStack(alignment: .leading, spacing: 15) {
            TextForgeSectionTitle(
                title: "本次更新",
                subtitle: "新东西都在这里，没拿旧功能凑数"
            )

            WhatsNewRow(
                icon: "chart.bar.fill",
                color: TextForgePalette.blue,
                title: "导入不卡了",
                detail: "文件在后台分块复制，并显示文件名、阶段、数量和真实字节进度。"
            )

            WhatsNewRow(
                icon: "doc.richtext.fill",
                color: TextForgePalette.violet,
                title: "Markdown 预览重做",
                detail: "后台解析和懒加载渲染，适配标题、列表、编号、引用、代码块与分隔线。"
            )

            WhatsNewRow(
                icon: "doc.badge.plus",
                color: .green,
                title: "文件导入修复",
                detail: "换用原生文档选择器，选中文件后点击“打开”会立即导入并进入编辑器。"
            )

            WhatsNewRow(
                icon: "sparkles.rectangle.stack.fill",
                color: TextForgePalette.violet,
                title: "每版更新说明",
                detail: "升级后首次启动自动展示本版变化，同一版本只显示一次。"
            )

            WhatsNewRow(
                icon: "app.badge.fill",
                color: TextForgePalette.blue,
                title: "正式 App 图标",
                detail: "桌面不再顶着系统默认白板，终于像个正经 App。"
            )

            WhatsNewRow(
                icon: "folder.fill.badge.plus",
                color: .orange,
                title: "从“文件”App 打开",
                detail: "在系统文件中选择 TextForge 后，会导入文稿并直接进入编辑器。"
            )
        }
        .textForgeGlassCard()
    }

    private var continueButton: some View {
        Button {
            dismiss()
        } label: {
            Label("开始使用", systemImage: "arrow.right.circle.fill")
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
    }
}

private struct WhatsNewRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(color.opacity(0.13))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.white.opacity(0.50), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

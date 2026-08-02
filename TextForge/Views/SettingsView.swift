import SwiftUI

struct SettingsView: View {
    private let repositoryURL = URL(string: "https://github.com/5488-ux/TextForge")!

    var body: some View {
        ZStack {
            TextForgeBackground()

            ScrollView {
                LazyVStack(spacing: 16) {
                    hero
                    featuresCard
                    changelogCard
                    projectCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var hero: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                TextForgeLogo(size: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text("TextForge")
                        .font(.system(size: 27, weight: .heavy, design: .rounded))
                    Text("版本 1.1.1 · 原生 SwiftUI")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                badge(icon: "iphone", title: "iOS 17+")
                badge(icon: "sparkles", title: "iOS 26")
                badge(icon: "lock.shield.fill", title: "本地编辑")
            }
        }
        .textForgeGlassCard()
    }

    private var featuresCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            TextForgeSectionTitle(
                title: "目前功能",
                subtitle: "不是画饼，这些现在就能用",
                trailingText: "5"
            )

            FeatureRow(
                icon: "square.and.arrow.down.fill",
                color: TextForgePalette.blue,
                title: "多格式导入",
                detail: "SRT、TXT、Markdown、代码、配置与更多文本格式"
            )
            FeatureRow(
                icon: "plus.rectangle.on.folder.fill",
                color: TextForgePalette.violet,
                title: "自定义新建",
                detail: "文件名和扩展名全由你决定"
            )
            FeatureRow(
                icon: "pencil.and.outline",
                color: .orange,
                title: "编辑与自动保存",
                detail: "UTF 文本编辑、重命名、分享和删除"
            )
            FeatureRow(
                icon: "doc.richtext.fill",
                color: .purple,
                title: "Markdown 双模式",
                detail: "修改和预览随时切换，支持 * 等 Markdown 标记"
            )
            FeatureRow(
                icon: "magnifyingglass",
                color: .green,
                title: "文件管理",
                detail: "搜索、排序、类型、体积和修改时间"
            )
        }
        .textForgeGlassCard()
    }

    private var changelogCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            TextForgeSectionTitle(
                title: "更新日志",
                subtitle: "每次更新到底改了什么"
            )

            timelineEntry(
                version: "1.1.1",
                date: "2026-08-02",
                text: "加入正式 App 图标，并修复从系统“文件”App 打开文稿没有反应的问题。"
            )

            Divider().opacity(0.45)

            timelineEntry(
                version: "1.1.0",
                date: "2026-08-02",
                text: "重做明亮液态玻璃界面，升级文件首页、新建页、编辑器和设置页。"
            )

            Divider().opacity(0.45)

            timelineEntry(
                version: "1.0.0",
                date: "2026-08-02",
                text: "文件导入、新建、编辑、Markdown 预览、自动保存和分享。"
            )
        }
        .textForgeGlassCard()
    }

    private var projectCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextForgeSectionTitle(
                title: "项目",
                subtitle: "源代码和构建配置都在这里"
            )

            Link(destination: repositoryURL) {
                HStack(spacing: 12) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(
                            LinearGradient(
                                colors: [TextForgePalette.blue, TextForgePalette.indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text("GitHub 仓库")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Text("5488-ux/TextForge")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption.bold())
                        .foregroundStyle(TextForgePalette.blue)
                }
                .padding(12)
                .background(.white.opacity(0.54), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(.white.opacity(0.78), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
        .textForgeGlassCard()
    }

    private func badge(icon: String, title: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption2.bold())
            .foregroundStyle(.primary.opacity(0.74))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(.white.opacity(0.54), in: Capsule())
            .overlay { Capsule().stroke(.white.opacity(0.80), lineWidth: 1) }
    }

    private func timelineEntry(version: String, date: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(TextForgePalette.blue)
                .frame(width: 9, height: 9)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(version)
                        .font(.subheadline.bold())
                    Spacer()
                    Text(date)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 43, height: 43)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.bold())
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(11)
        .background(.white.opacity(0.48), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }
}

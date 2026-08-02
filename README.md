# TextForge

TextForge 是一个原生 SwiftUI iOS 文本编辑器，支持从“文件”App 导入、创建、编辑、预览和分享文本文件。

## 功能

- 导入任意可读取的文本文件，包括 SRT、TXT、Markdown、JSON、CSV、YAML、XML、HTML、CSS、JavaScript、Swift、Python、日志和自定义扩展名
- 新建文件时自由填写文件名与扩展名
- Markdown 编辑与渲染预览
- 自动保存、手动保存、重命名、分享和删除
- 文件搜索、类型标识、修改时间与字符统计
- iOS 26 Liquid Glass 外观，并兼容 iOS 17 及以上系统
- 设置页内置功能清单、更新日志和 GitHub 链接

## Codemagic 无签名 IPA

仓库根目录的 `codemagic.yaml` 会使用 Xcode 26.0：

1. 验证 Xcode Project、Shared Scheme 和 Target ID
2. 解析 Swift Package（当前项目没有第三方依赖，此步骤仍会验证工程依赖图）
3. 使用 `iphoneos`、`Release`、`CODE_SIGNING_ALLOWED=NO` 构建
4. 将 `TextForge.app` 放入 `Payload`
5. 生成并验证 `build/ios/ipa/TextForge-unsigned.ipa`

无签名 IPA 不能直接通过 App Store 安装，需要自行签名或使用支持重签名的安装方式。

## 本地打开

需要 macOS 与 Xcode 26。打开 `TextForge.xcodeproj`，选择 `TextForge` Scheme 后运行。

## License

MIT

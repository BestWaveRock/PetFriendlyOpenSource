# PetFriendly iOS — AI Agent 约定

供所有 AI Coding Agent 进场合入协作时遵循的硬性约定。**先读此文件再动手。**

## ⚠️ 新增 Swift 文件必须加入 Xcode 工程

- 本仓库 Xcode 工程使用**显式文件引用**（`project.pbxproj` 中的 PBXBuildFile / PBXFileReference / PBXGroup）。
- **新建任何 `.swift` 文件（新 View、新组件、新工具类等）后，必须用 `xcodeproj` gem 将其加入工程文件 `PetFriendly.xcodeproj/project.pbxproj`**，否则编译会报 `cannot find in scope` / 符号找不到。
- 推荐添加方式（在项目根目录执行）：
  ```bash
  ruby -e 'require "xcodeproj"; proj = Xcodeproj::Project.open("PetFriendly.xcodeproj"); target = proj.targets.find { |t| t.name == "PetFriendly" }; target.add_file_reference("PetFriendly/Views/XXX/NewFile.swift"); proj.save'
  ```
  请把路径替换为实际文件路径。也可手动编辑 pbxproj 把文件挂到正确的 group，但建议优先用 gem 避免手工改坏工程结构。
- **禁止**只创建 Swift 文件而不加入工程后直接提交。

## 弹窗 / 支付密码等 SwiftUI 状态约定

- `fullScreenCover(isPresented:)` / `.sheet(isPresented:)` 的 content 闭包会**捕获过期的 `@State`**（标题、金额等），导致首次触发时显示错误数据。
- **统一用 `.fullScreenCover(item:)` / `.sheet(item:)`** 配 `Identifiable` 配置结构体，把需要用到的数据作为参数直接传给弹窗内容。
- 涉及支付密码校验的弹窗统一走 `PaymentPasswordGate`（见 `Views/Me/Settings/PaymentPasswordGate.swift`）。

## 弹窗体验约定（B 方案）

- 点按钮后弹窗不应立即关闭：需等异步接口返回，**成功才关闭**，失败保留并可重试；期间展示加载态。

## Git / 发布约定

- 分支：`develop`（开发）、`github-actions`（构建）、`main`（发布）。
- 改完代码默认直接 commit + push，除非用户明确说明。
- 详见 `DEVELOPER_GUIDE.md`（密钥脱敏、CI 注入、打包流程）。

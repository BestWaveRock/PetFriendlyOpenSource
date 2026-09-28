# 🐾 开发者与 AI Agent 协做交接指南 (Developer & AI Agent Guide)

欢迎来到《宠物友好指南》（PetFriendly）项目！本指南旨在为人类协作者以及未来进场协助开发的 **AI Coding Agent** 提供完整的上下文交代，确保后续能够快速融入、理解工作流并无缝执行编码任务。

---

## 🏗️ 一、 项目概览与关键架构 (Project Architecture)

* **技术栈**：SwiftUI (iOS 16.0+) + MapKit (UIKit 桥接 SwiftUI 驱动) + CocoaPods。
* **设计风格**：**iOS 26/27 拟态微动美学**，融入液态渐变色、Capsule 胶囊菜单以及阻尼物理弹簧过渡。
* **安全存储层**：用户的 `access_token` 的本地持久化已被整体迁移至原生钥匙串 **[KeychainManager.swift](PetFriendly/Helpers/KeychainManager.swift)** 物理加密托管，禁止使用高风险的 `UserDefaults`。
* **原生 UI 加载组件**：
  * 转圈加载：使用 [SpinLoading.swift](PetFriendly/Views/Utils/SpinLoading.swift)。
  * 步骤条：使用自定义的高拟态弹簧渐变加载栏 [PFProgressBar.swift](PetFriendly/Views/Utils/PFProgressBar.swift)，进度缩放由 `.scaleEffect(anchor: .leading)` 驱动，**杜绝使用 GeometryReader 以免在弹性垂直布局中发生宽度塌陷**。

---

## 🔒 二、 开源安全脱敏机制 (Security Configuration)

本项目已完成深度开源脱敏，所有密钥（RSA公私钥、X-APP-KEY、clientId）以及生产 API 域名已彻底外部化：

1. **本地私密文件**：**`PetFriendly/Secrets.swift`**（包含真实 API 与密钥，已被写入 `.gitignore` 彻底防漏泄隔离）。
2. **开源模板文件**：**[Secrets.example.swift](PetFriendly/Secrets.example.swift)**。
   * *注意*：为规避 Swift 编译期 Module 命名空间重复声明（invalid redeclaration）冲突，模板结构体已重命名为 `struct SecretsTemplate`。
3. **一键加密同步配置脚本**：
   * 本地临时目录下有 `set_github_secret.py`。该脚本利用 libsodium 的 `crypto_box_seal` 加密算法，读取本地 `Secrets.swift` 整体源码并一键加密上传为 GitHub 仓库 Repository Secret：**`SECRETS_SWIFT_CONTENT`**。

---

## 🚀 三、 CI/CD 编译与 Secrets 注入流水线 (CI/CD Pipeline)

云端打包工作流在 **[.github/workflows/ios.yml](.github/workflows/ios.yml)** 中定义，运行在 `macos-15` / 最新稳定版 Xcode 环境中：

1. **双引号转义注入防线**：
   在 `Inject Secrets Config` 步骤中，GitHub Actions 必须通过 **环境变量中转** 传入 Secret 内容，即：
   ```yaml
   env:
     SECRETS_CONTENT: ${{ secrets.SECRETS_SWIFT_CONTENT }}
   run: |
     echo "$SECRETS_CONTENT" > PetFriendly/Secrets.swift
   ```
   **AI Agent 警示**：绝对不要在 run 命令中直接 `echo "${{ secrets.SECRETS_SWIFT_CONTENT }}"`展开，否则 Shell 在求值时会静默剥离双引号，引起 Swift 编译崩溃。
2. **构建 Fallback 兜底与动态替换**：
   在 `SECRETS_SWIFT_CONTENT` 为空（例如外部开发者 Fork 仓库）时，构建会自动拷贝 example 模版并利用 `sed` 将 `SecretsTemplate` 动态命名替换为 `Secrets`，防止因缺符号中断打包。

---

## 👥 四、 Git 分支流与发布 Pipeline 规范 (Git Workflow)

为了最大化节省 GitHub Actions 算力与费用额度，我们规定了严整的 Git 工作流：

1. **分支设定**：
   * **`develop`**：**开发分支**。所有日常开发、代码编写、新 Feature 提交一律在 `develop` 进行。
   * **`github-actions`**：**构建分支**。仅在需要打包出包时作为中转合入。
   * **`main`**：**正式发布分支**。
2. **标准流水线 Pipeline 操作规范 (AI Agent & Developer 必须执行)**：
   * **第一步 (开发)**：在本地 `develop` 分支进行编码。
   * **第二步 (提交)**：在本地提交，**注意**：`PetFriendly.ipa` 已经被 `git rm --cached` 注销追踪，绝不要强制提交打包。
   * **第三步 (合入构建)**：将 `develop` 合并至 `github-actions` 并推送，激活云端打包：
     ```bash
     git checkout github-actions && git merge develop && git push origin github-actions
     ```
   * **第四步 (编译包测试)**：Actions 编译 `success` 后，最新包会自动生成在 Releases 里。
   * **第五步 (合并发布)**：测试无误后，通过 GitHub 提起 Pull Request，将 `github-actions` 合并至 `main` 分支进行正式发布。
   * **第六步 (回归)**：完成 PR 后，将本地切回 `develop` 继续编码。

---

## 🛠️ 五、 本地编译与排错 (Local Compilation)

1. **初始化 Xcode CLT**：
   在同意 `sudo xcodebuild -license` 后，必须运行 `sudo xcodebuild -runFirstLaunch` 加载 DVT 依赖，本地 CLI 才能正常编译。
2. **Git 忽略过滤**：
   本地编译会产生临时衍生目录 **`dd/`**。请注意它已被写进 `.gitignore`，切忌以 `--force` 方式将其强行提交入库造成缓存污染。

---

## 🔢 六、 后端 ID 与 iOS 解码规范

后端会将 Java `Long` 类型的标识符自动序列化为 JSON 字符串，以避免大整数在客户端传输和解析时丢失精度。iOS 端必须遵循以下规则：

1. 响应模型中名为 `id`、`xxId`、`xx_id` 的标识符字段统一使用 `String`，`Identifiable.ID` 也必须保持为 `String`。
2. 禁止直接使用 `Int`、`Int64`、`Double` 或 `NSNumber` 接收后端 ID 响应。
3. 兼容历史接口时，应优先解码 `String`；仅将数字响应作为兜底，并立即转换成 `String`。
4. 只有某个请求参数或本地 API 明确要求数字时，才允许在调用边界临时转换，响应模型内部仍保留字符串。

示例：

```swift
struct Record: Decodable, Identifiable {
    let recordId: String
    var id: String { recordId }
}
```

# 开发者指南 (Developer Guide)

面向参与本项目的开发者。产品功能与构建步骤见 [README.md](README.md)，本文只讲架构约定与编码规范。

## 架构概览

- **技术栈**：SwiftUI（最低部署目标 iOS 16.0）+ MapKit（通过 UIKit 桥接到 SwiftUI）
- **网络层**：[NetworkManager.swift](PetFriendly/Services/Network/NetworkManager.swift) 统一处理请求、鉴权与错误；[AuthService.swift](PetFriendly/Services/Network/AuthService.swift) 负责登录注册
- **依赖**：Alamofire（实际使用）与 swift-algorithms（本地包声明，见 README 说明），两者都是**本地 Swift Package**，必须放在工程文件的同级目录
- **配置**：所有环境相关的地址与密钥集中在 `PetFriendly/Secrets.swift`（不入版本控制），模板见 [Secrets.example.swift](PetFriendly/Secrets.example.swift)

### 安全存储

用户的 `access_token` 等凭证统一由 [KeychainManager.swift](PetFriendly/Helpers/KeychainManager.swift) 写入系统钥匙串，**禁止用 `UserDefaults` 存放任何凭证**。

### 通用 UI 组件

- 转圈加载：[SpinLoading.swift](PetFriendly/Views/Utils/SpinLoading.swift)
- 步骤条：[PFProgressBar.swift](PetFriendly/Views/Utils/PFProgressBar.swift)，进度缩放由 `.scaleEffect(anchor: .leading)` 驱动。**不要改用 `GeometryReader`**，在弹性垂直布局中会导致宽度塌陷

## 配置注入机制

`Secrets.swift` 由模板拷贝而来。模板的结构体名是 `SecretsTemplate` 而不是 `Secrets`，这样模板与本地真实文件可以同时存在于工程中，不会产生重复声明的编译错误。

CI 通过仓库 Secret `SECRETS_SWIFT_CONTENT` 注入真实配置：

```yaml
env:
  SECRETS_CONTENT: ${{ secrets.SECRETS_SWIFT_CONTENT }}
run: |
  echo "$SECRETS_CONTENT" > PetFriendly/Secrets.swift
```

**必须经由环境变量中转。** 若在 `run` 中直接写 `echo "${{ secrets.SECRETS_SWIFT_CONTENT }}"`，Shell 求值时会剥掉双引号，生成的 Swift 文件语法错误、编译失败。

当该 Secret 为空时（例如外部 fork 仓库），CI 会回退到模板并把 `SecretsTemplate` 替换为 `Secrets`，保证仍能编译，但构建产物无法连接真实后端。

在本地写入该 Secret：

```bash
gh secret set SECRETS_SWIFT_CONTENT --body "$(cat PetFriendly/Secrets.swift)"
```

## 后端 ID 解码规范

后端会把 Java `Long` 类型的标识符序列化为 JSON 字符串，以避免大整数在客户端解析时丢精度。iOS 端必须遵守：

1. 响应模型中 `id`、`xxId`、`xx_id` 这类标识符字段统一使用 `String`，`Identifiable.ID` 同样保持 `String`
2. 禁止用 `Int`、`Int64`、`Double` 或 `NSNumber` 接收后端 ID
3. 兼容历史接口时优先解码 `String`，数字响应只作兜底并立即转成 `String`
4. 仅当请求参数或本地 API 明确要求数字时，才在调用边界临时转换，响应模型内部仍保持字符串

```swift
struct Record: Decodable, Identifiable {
    let recordId: String
    var id: String { recordId }
}
```

## 提交与发布

- 仓库使用单分支 `main`
- CI（[.github/workflows/ios.yml](.github/workflows/ios.yml)）为**手动触发**：在 Actions 页面 Run workflow，会按现有 `v*` tag 计算下一个版本号、无签名构建并创建 Release
- 不要提交构建产物：`*.ipa`、`dd/`、`build/`、`DerivedData/` 均已在 `.gitignore` 中，不要用 `--force` 强行加入

## 本地编译注意

首次使用命令行编译前，需要先同意许可并加载 DVT 依赖，否则 CLI 构建会失败：

```bash
sudo xcodebuild -license
sudo xcodebuild -runFirstLaunch
```

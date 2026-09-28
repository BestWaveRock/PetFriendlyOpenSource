# 宠物友好指南 | PetFriendly 🐾

[![Build Status](https://img.shields.io/badge/Build-passing-brightgreen.svg)]()
[![iOS Support](https://img.shields.io/badge/iOS-15.0+-blue.svg)]()
[![Xcode Support](https://img.shields.io/badge/Xcode-26.4.1+-orange.svg)]()
[![License](https://img.shields.io/badge/License-Apache_2.0-yellow.svg)](LICENSE)

* 🎨 **原型设计**：[小草皮宠物友好地图 - MasterGo 协作原型](https://mastergo.com/goto/M43ChUuG?page_id=M&layer_id=2:1899&proto=1&shared=true)
* 📱 **配套 Android 端**：[PetFriendly-Android](https://github.com/BestWaveRock/PetFriendly-Android)

---

## 🌟 产品理念 (Product Philosophy)

**“毛孩子是家人，不是身外之物。带宠物出门不应该是一场冒险，而应该是一段优雅、轻松的旅程。”**

《宠物友好指南》（PetFriendly）是一款面向宠物主人的高品质社区化导航与萌宠管理应用。我们致力于通过**社区共建模式**建立起一个有温度的“宠物友好地图”，连接人类、宠物与城市空间。打破人宠出行的物理隔阂，让养宠生活更加健康、有爱、便捷。

---

## 🚫 痛点解决 (Addressed Pain Points)

在繁华的都市生活中，携宠出行常常伴随着各种不确定性。PetFriendly 终结了三大核心痛点：

1. **出行全靠猜，到店被拒之门外**
   - **痛点**：缺乏公开的宠物友好商家标准，带狗出门到了餐厅或公园才发现禁止入内。
   - **解决**：提供多维度分类地图标记，直观展现场所的宠物友好等级，细化至“允许室内”、“仅室外”、“必须牵绳/装箱”等限制规则，所有数据由真实社区用户共建和审核。
2. **突发状况手忙脚乱，错失黄金救援时间**
   - **痛点**：宠物突发急性疾病、吞食异物或受伤时，难以及时找到最近的 24 小时宠物急救中心，且缺乏专业的紧急处理指导。
   - **解决**：内置 **24小时宠物急救系统**，一键检索并导航至最近的宠物医院。同时支持一键关联宠物档案，让专家更快评估状况，争取黄金救援时间。
3. **健康记录零散，疫苗与美容提醒经常漏掉**
   - **痛点**：疫苗接种本容易丢失，美容与除虫周期难以记忆。
   - **解决**：智能“萌宠绿洲”健康档案，根据上一次接种或美容时间，计算推荐区间并自动唤起本地通知与消息提醒，做到真正的智能省心。

---

## 🎨 功能设计 (Functional Design)

PetFriendly iOS 客户端融入了 **iOS 26/27 微动美学**，呈现出极致的交互体验：

### 1. 极致液态玻璃菜单栏 (Liquid Glass Navigation)
* **动态流光折射**：采用 SwiftUI `TimelineView` 结合流态 `AngularGradient` 渲染出真实的动态玻璃质感。光晕与边框高光随时间缓缓旋转，展现极佳的折射感。
* **果冻拉伸动画**：切换 Tab 时，选中的 Capsule 背景激活 `GeometryReader` 物理计算，在横向移动时产生形如水滴的横向拉伸（`tabStretch`）与惯性收缩，带来极致的有机交互动效。
* **触感微动弹簧**：每次点击 Tab 或搜索按钮，图标将获得物理弹簧缩放反馈，并触发中度振动反馈。

### 2. 智能友好地图
* **多级半径过滤**：支持 5km、20km、50km、无限制（1000km）范围切换，精准控制检索圈。
* **快捷检索卡片**：在探索模式下，底部卡片动态呈现当前视窗内的场所统计，且支持一键隐藏以还原全屏地图。

### 3. 萌宠绿洲 (Pet Oasis)
* **AI 4K 证件照生成**：接入 Doubao AI 视觉模型，自动识别毛发与五官，消耗积分一键生成大片级 4K 宠物证件照并支持保存至系统相册。
* **健康与生活里程碑**：以精美的时间轴管理疫苗、美容、体检、绝育、驱虫等核心事件。

### 4. 系统设置与热更新
* **一键检查更新**：应用关于页面支持通过 GitHub REST API 检索仓库最新的打包发布（Releases）信息。
* **语义版本比对**：自动解析 Semver 版本号进行对比，如发现新版本直接弹窗引导用户跳转浏览器下载最新 `.ipa` 包。

---

## 🛠 开发集成与构建 (Developer Integration)

> 💡 **AI Agent 与协作者必读**：有关详细的架构模块、Secret 动态配置和 Git 分支 Pipeline 提交规范，请务必先查阅：[开发者与 AI Agent 协做交接指南](DEVELOPER_GUIDE.md)。

本项目的 CI/CD 流程高度自动化，支持自动递增版本号并将其写入二进制。

### 1. CI/CD 持续集成 (GitHub Actions)
项目的持续集成在 [ios.yml](.github/workflows/ios.yml) 中定义：
* **执行平台**：`macos-15` 环境，搭载最新稳定版 Xcode（CI 中通过 `setup-xcode` 取 `latest-stable`）。
* **版本自动递增**：在代码编译前，脚本会自动抓取远程 Git 仓库的 tag，通过 Shell 计算出递增的 Semver 标签（如 `v1.0.1` -> `v1.0.2`），并通过环境变量 `APP_VERSION` 注入 Xcode 编译阶段。
* **发布归档**：编译通过后，使用 `softprops/action-gh-release` 自动在仓库创建对应版本的 Release，并把编译出的 `PetFriendly.ipa` 附加到资产中。

### 2. 本地版本自动生成
在本地编译项目时，Xcode 的 Run Script Phase 会自动触发 [update_build_info.sh](scripts/update_build_info.sh)：
* 该脚本会自动提取当前 Git Commit Hash，并生成 [Version.generated.swift](PetFriendly/Utils/Version.generated.swift)：
```swift
enum AppVersion {
    static let gitHash = "d0422c8"
    static let version = "1.0.1"
}
```
* **关于设置页**中的版本号显示和更新比对逻辑全部依赖此文件。

### 3. 本地命令行构建 workflow
如果您希望在本地以命令行模式打包、安装和调试 App：

```bash
# 1. 克隆必要依赖（请确保与 PetFriendly 同级）
cd ..
git clone https://github.com/Alamofire/Alamofire.git
git clone https://github.com/apple/swift-algorithms.git

# 2. 执行编译命令（无签名调试包）
cd PetFriendly
xcodebuild clean build \
  -project "PetFriendly.xcodeproj" \
  -scheme "PetFriendly" \
  -configuration Debug \
  -sdk iphoneos \
  -destination generic/platform=iOS \
  -derivedDataPath "dd" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  INFOPLIST_FILE="Info.plist"

# 3. iOS 17+ 真机安装 (CoreDevice 架构)
# 获取真机 Device ID 
xcrun devicectl list devices
# 安装编译出的 app 包
xcrun devicectl device install app --device <DEVICE_ID> dd/Build/Products/Debug-iphoneos/PetFriendly.app
```

### 4. 外部私密配置 (Secrets)
由于本项目已做开源安全脱敏，真实的 API 域名、加解密公钥私钥等敏感配置已被抽离。本地运行前，请执行以下步骤：
1. 在项目源码目录中，将 `PetFriendly/Secrets.example.swift` 复制并重命名为 `PetFriendly/Secrets.swift`。
2. 打开 `Secrets.swift`，填入您自己的配置（如 API 基础域名、客户端 ID 以及加解密密钥）。
*提示：`Secrets.swift` 已被写入 `.gitignore`，切勿将其提交到任何公开仓库中。*

---

## 👥 贡献者名单 (Contributors)

感谢所有为本项目做出贡献的开发者！
Thank you to all the contributors of this project!

<a href="https://github.com/BestWaveRock/PetFriendly/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=BestWaveRock/PetFriendly" />
</a>

---

## 📄 开源许可证 (License)

本软件基于 **非商业性开源软件许可协议** 开源。详情请参见 [LICENSE](LICENSE) 文件。
版权所有 © 2026 BestWaveRock。本软件著作权归作者个人所有，允许个人学习使用，禁止商业使用。

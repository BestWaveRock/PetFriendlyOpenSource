# 宠物友好指南 (PetFriendly)

![Platform](https://img.shields.io/badge/Platform-iOS%2016.0%2B-blue.svg)
![UI](https://img.shields.io/badge/UI-SwiftUI-orange.svg)
[![License](https://img.shields.io/badge/License-非商业%20Non--Commercial-red.svg)](LICENSE)

面向宠物主人的「宠物友好场所」地图与宠物管理 App，iOS 客户端，SwiftUI 实现。

带宠物出门时最常见的问题是「这家店到底让不让进、附近有没有能去的地方」。PetFriendly 用社区共建的场所地图回答这个问题，并把宠物档案、健康提醒、服务预约和急救求助整合在同一个 App 里。

---

## 产品

### 宠物友好地图
- 多级半径过滤：5km / 20km / 50km / 不限，地图与列表双视图切换
- 场所详情，标注宠物友好规则（可否进室内、是否仅限室外、是否需牵绳或装箱等）
- 关键词搜索与分类筛选
- 用户投稿新场所、对已有场所提交评价

### 附近宠友
- 按距离浏览附近宠友，查看名片与宠物信息
- 基于会话的聊天，支持文字、图片与语音输入

### 萌宠档案
- 宠物档案与成长记录
- 健康记录：疫苗、驱虫、体检、美容、绝育等事件的时间轴
- 萌宠提醒：按上次记录推算下次时间（如美容周期、生日）并发送本地通知
- 宠物回收站，误删可恢复

### 服务
- AI 生成宠物证件照
- 寄养服务预约、通用服务预约、领养登记
- AI 宠物健康助手：流式对话，支持上传图片并关联宠物档案，覆盖日常养护、健康科普与急救引导；内置「附近医院」入口与急救记录

### 账号与设置
- 注册登录（账号 / 邮箱 / 验证码，网络层支持 RSA 加密传输）
- 积分商城、钱包与订单
- 内容安全：发布前自动过滤 + 人工审核流程、举报与屏蔽
- 隐私政策、用户协议与账号注销
- 检查更新：比对语义版本号并引导下载新版本
- 多语言：简体中文、English

---

## 关于本仓库

**本仓库只包含 iOS 客户端，不包含服务端。**

地图数据、账号体系、AI 能力、内容审核、订单与积分等全部依赖后端接口。相关的地址与密钥统一在 `PetFriendly/Secrets.swift` 中配置（见下方「配置 Secrets」）。

未配置真实后端时，工程可以正常编译和运行，但登录、地图、AI 等功能不可用。

---

## 开发

### 环境要求

| 项 | 要求 |
|---|---|
| 系统 | macOS |
| Xcode | 能编译 SwiftUI 的较新版本均可（CI 使用 `macos-15` + `latest-stable`） |
| Swift | 5.0 语言模式（工程现有设置） |
| 最低部署目标 | iOS 16.0 |

工程未绑定特定 iOS SDK（`SDKROOT = iphoneos`），以本机 Xcode 自带的 SDK 构建。

### 依赖

工程通过 `XCLocalSwiftPackageReference` 引用两个**本地 Swift Package**，路径相对工程文件为 `../Alamofire` 和 `../swift-algorithms`。因此必须把这两个包克隆到与项目**同级**的目录：

```bash
# 假设当前位于项目根目录
cd ..
git clone https://github.com/Alamofire/Alamofire.git
git clone https://github.com/apple/swift-algorithms.git
```

仓库里的 `Podfile` / `Podfile.lock` 是历史遗留文件，实际构建**不走 CocoaPods**，无需执行 `pod install`。

### 配置 Secrets

真实的 API 地址与密钥已从源码中抽离，集中放在一个不入版本控制的文件里：

1. 复制模板：`PetFriendly/Secrets.example.swift` → `PetFriendly/Secrets.swift`
2. 填入你自己的配置：API 基础域名、clientId、X-APP-KEY、RSA 公私钥、对象存储地址、联系邮箱等

`Secrets.swift` 已被 `.gitignore` 忽略，**请勿提交到任何公开仓库**。缺失该文件时，`package.sh` 会自动从模板生成一份（内容为占位符）。

### 本地构建

**方式一：脚本（推荐）**

```bash
bash package.sh            # 构建无签名 IPA
bash package.sh install    # 构建 + 签名 + 通过 ios-deploy 安装到真机
```

签名参数通过环境变量传入，不要写进仓库：

```bash
TEAM_ID=你的TeamID \
BUNDLE_ID=com.example.petfriendly \
CODESIGN_IDENTITY="Apple Development: you@example.com (你的TeamID)" \
DEVICE_ID=你的设备UDID \
KEYCHAIN_PASSWORD=你的钥匙串口令 \
bash package.sh install
```

**方式二：手动 xcodebuild**

```bash
xcodebuild clean build \
  -project "PetFriendly.xcodeproj" \
  -scheme "PetFriendly" \
  -configuration Debug \
  -sdk iphoneos \
  -destination generic/platform=iOS \
  -derivedDataPath "dd" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

# 安装到真机（iOS 17+）
xcrun devicectl list devices
xcrun devicectl device install app --device <DEVICE_ID> \
  dd/Build/Products/Debug-iphoneos/PetFriendly.app
```

首次在 Xcode 中打开工程时，需要在 Signing & Capabilities 里选择你自己的 Team（工程内未预设 Team ID）。

### 目录结构

```
PetFriendly/
├── Views/            界面层
│   ├── Map/          地图、场所详情、投稿与评价
│   ├── Pets/         宠物档案、成长与健康记录
│   ├── Services/     证件照、寄养预约、领养、急救对话
│   ├── ChatUI/       聊天界面组件
│   ├── Me/           登录注册、个人中心、设置、积分商城
│   ├── User/         用户名片与资料编辑
│   └── Components/   通用组件（缓存图片、对话框、内容安全等）
├── Services/         网络层与业务服务（Auth、NetworkManager、Watch 连接）
├── Utils/            工具（钥匙串、RSA 加解密、缓存、动效组件）
├── en.lproj/         英文文案
├── zh-Hans.lproj/    简体中文文案
└── PrivacyInfo.xcprivacy
```

### 持续集成

`.github/workflows/ios.yml`，**手动触发**（`workflow_dispatch`），流程为：

1. 读取现有 `v*` tag 计算下一个版本号
2. 克隆两个依赖到上级目录
3. 从仓库 Secret `SECRETS_SWIFT_CONTENT` 注入 `Secrets.swift`；Secret 为空时回退到模板
4. 无签名构建并打包 `PetFriendly.ipa`
5. 上传构建产物，并按新版本号创建 Release、附上 IPA

在 fork 或未配置 `SECRETS_SWIFT_CONTENT` 的仓库中，第 3 步会使用占位符配置，构建出的 App 无法连接真实后端。

---

## 授权 (License)

本项目采用**允许个人非商业使用、禁止商业使用**的许可协议：

- ✅ 个人学习、研究、教学、测试与个人娱乐等非商业用途，可自由复制、修改、分发
- ❌ 任何商业用途均需事先取得书面授权

本软件的著作权归作者 **BestWaveRock 个人所有**，本许可**不构成任何著作权的转让**。

完整条款见 [LICENSE](LICENSE)。商业授权请联系 **Springerpaw@gmail.com**。

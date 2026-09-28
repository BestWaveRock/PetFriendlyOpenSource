import Foundation

/// ⚠️ 开源配置模板：请拷贝此文件并命名为 Secrets.swift，填入你自己的配置
struct SecretsTemplate {
    static let clientId = "YOUR_CLIENT_ID"
    static let appKey = "YOUR_X_APP_KEY"
    static let defaultBaseURL = "https://your-api.domain.com/prod-api"
    static let localDevURL = "http://your-local-dev-ip:3100/prod-api"
    static let encryptPublicKey = "YOUR_RSA_PUBLIC_KEY"
    static let defaultBannerURL = "https://your-domain.com/path/to/default-banner.jpg"
    static let encryptPrivateKey = "YOUR_RSA_PRIVATE_KEY"

    // MARK: - 对象存储 / 文件分发

    /// 文件分享服务根地址，IPA 下载链接格式: <fileHostBaseURL>/PetFriendly-x.y.z.ipa
    static let fileHostBaseURL = "https://your-file-host.example.com/@s/YOUR_SHARE_TOKEN"
    /// 文件列表接口
    static let fileListURL = "https://your-file-host.example.com/api/fs/list"
    /// 文件分享路径段，POST /api/fs/list 的 path 参数
    static let fileSharePath = "/@s/YOUR_SHARE_TOKEN"
    /// 对象存储基址（相对路径拼接用），末尾不带 /
    static let objectStorageBaseURL = "https://your-object-storage.example.com/your-bucket"

    // MARK: - 对外联系方式

    static let privacyEmail = "privacy@example.com"
    static let supportEmail = "support@example.com"
    static let contactEmail = "contact@example.com"
    static let privacyPolicyURL = "https://your-domain.example.com/privacy"
}

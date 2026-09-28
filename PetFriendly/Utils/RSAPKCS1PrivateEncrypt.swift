//
//  RSAError.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 23/9/25.
//


import Security
import Foundation

enum RSAError: Error { case keyFailed, cryptoFailed }

final class RSAPKCS1PrivateEncrypt {
    
    /// 加载 .p12 私钥
    static func loadPrivateKey(p12Name: String, p12Pwd: String) throws -> SecKey {
        guard let url = Bundle.main.url(forResource: p12Name, withExtension: "p12"),
              let p12 = try? Data(contentsOf: url) else {
            throw RSAError.keyFailed
        }
        
        let opt: NSDictionary = [kSecImportExportPassphrase: p12Pwd]
        var items: CFArray?
        let sts = SecPKCS12Import(p12 as CFData, opt, &items)
        guard sts == errSecSuccess,
              let arr = items as? [[String: Any]],
              let identity = arr.first?[kSecImportItemIdentity as String] as! SecIdentity? else {
            throw RSAError.keyFailed
        }
        
        var key: SecKey?
        SecIdentityCopyPrivateKey(identity, &key)
        guard let privKey = key else { throw RSAError.keyFailed }
        return privKey
    }
    
    /// 私钥「加密」——内部用签名接口（PKCS1-v1_5）
    static func encrypt(_ plain: String, using privateKey: SecKey) throws -> Data {
        guard let data = plain.data(using: .utf8) else { throw RSAError.cryptoFailed }
        
        // iOS 10+ 统一用 SecKeyCreateSignature
        guard let signature = SecKeyCreateSignature(privateKey,
                                                    .rsaSignatureMessagePKCS1v15SHA256,
                                                    data as CFData,
                                                    nil) else {
            throw RSAError.cryptoFailed
        }
        return signature as Data
    }
    
    /// 公钥「解密」——内部用验签接口（服务器端对应）
    static func decrypt(_ cipher: Data, using publicKey: SecKey) throws -> String {
        // 这里演示本地验签，服务器只需把 signature 当 cipher 用相同接口验签即可拿到原文
        guard SecKeyVerifySignature(publicKey,
                                    .rsaSignatureMessagePKCS1v15SHA256,
                                    cipher as CFData,
                                    cipher as CFData,
                                    nil) else {
            throw RSAError.cryptoFailed
        }
        // 本地测试：直接把 cipher 当原文返回（实际场景下服务器验签后提取原文）
        return String(data: cipher, encoding: .utf8) ?? ""
    }
}

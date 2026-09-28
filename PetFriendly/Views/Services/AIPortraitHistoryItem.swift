import SwiftUI

struct AIPortraitHistoryItem: Identifiable, Decodable {
    let id: Int64
    let originalUrl: String
    let generatedUrl: String
    let createTime: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case originalUrl = "original_url"
        case generatedUrl = "generated_url"
        case createTime = "create_time"
    }
}



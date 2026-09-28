import Foundation

enum LegalDocument: String, Identifiable, CaseIterable {
    case privacy
    case terms
    case community
    case ai

    static let version = "2026-08-11"
    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacy: return NSLocalizedString("legal_privacy_title", comment: "")
        case .terms: return NSLocalizedString("legal_terms_title", comment: "")
        case .community: return NSLocalizedString("legal_community_title", comment: "")
        case .ai: return NSLocalizedString("legal_ai_title", comment: "")
        }
    }

    var body: String {
        switch self {
        case .privacy: return NSLocalizedString("legal_privacy_body", comment: "")
        case .terms: return NSLocalizedString("legal_terms_body", comment: "")
        case .community: return NSLocalizedString("legal_community_body", comment: "")
        case .ai: return NSLocalizedString("legal_ai_body", comment: "")
        }
    }
}

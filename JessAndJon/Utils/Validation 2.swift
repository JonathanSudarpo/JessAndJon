import Foundation

// MARK: - Input Validation
struct Validation {
    // Maximum lengths
    static let maxNameLength = 50
    static let maxCaptionLength = 500
    static let maxNoteLength = 500
    static let maxStatusTextLength = 100
    static let partnerCodeLength = 6
    
    // Validate and sanitize name
    static func validateName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            throw ValidationError.emptyName
        }
        
        guard trimmed.count <= maxNameLength else {
            throw ValidationError.nameTooLong(maxLength: maxNameLength)
        }
        
        // Remove any control characters
        let sanitized = trimmed.components(separatedBy: .controlCharacters).joined()
        
        return sanitized
    }
    
    // Validate and sanitize caption
    static func validateCaption(_ caption: String?) -> String? {
        guard let caption = caption else { return nil }
        
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return nil
        }
        
        if trimmed.count > maxCaptionLength {
            // Truncate if too long (silently, or could throw)
            return String(trimmed.prefix(maxCaptionLength))
        }
        
        // Remove control characters
        let sanitized = trimmed.components(separatedBy: .controlCharacters).joined()
        
        return sanitized.isEmpty ? nil : sanitized
    }
    
    // Validate and sanitize note text
    static func validateNote(_ note: String) throws -> String {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            throw ValidationError.emptyNote
        }
        
        guard trimmed.count <= maxNoteLength else {
            throw ValidationError.noteTooLong(maxLength: maxNoteLength)
        }
        
        // Remove control characters
        let sanitized = trimmed.components(separatedBy: .controlCharacters).joined()
        
        return sanitized
    }
    
    // Validate and sanitize status text
    static func validateStatusText(_ text: String?) -> String? {
        guard let text = text else { return nil }
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return nil
        }
        
        if trimmed.count > maxStatusTextLength {
            return String(trimmed.prefix(maxStatusTextLength))
        }
        
        // Remove control characters
        let sanitized = trimmed.components(separatedBy: .controlCharacters).joined()
        
        return sanitized.isEmpty ? nil : sanitized
    }
    
    // Validate partner code format
    static func validatePartnerCode(_ code: String) throws -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        guard trimmed.count == partnerCodeLength else {
            throw ValidationError.invalidPartnerCodeLength
        }
        
        // Check if contains only valid characters (letters and numbers, excluding confusing ones)
        let validCharacters = CharacterSet(charactersIn: "ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        guard trimmed.unicodeScalars.allSatisfy({ validCharacters.contains($0) }) else {
            throw ValidationError.invalidPartnerCodeCharacters
        }
        
        return trimmed
    }
}

// MARK: - Validation Errors
enum ValidationError: LocalizedError {
    case emptyName
    case nameTooLong(maxLength: Int)
    case emptyNote
    case noteTooLong(maxLength: Int)
    case invalidPartnerCodeLength
    case invalidPartnerCodeCharacters
    
    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Name cannot be empty"
        case .nameTooLong(let max):
            return "Name must be \(max) characters or less"
        case .emptyNote:
            return "Note cannot be empty"
        case .noteTooLong(let max):
            return "Note must be \(max) characters or less"
        case .invalidPartnerCodeLength:
            return "Partner code must be 6 characters"
        case .invalidPartnerCodeCharacters:
            return "Partner code contains invalid characters"
        }
    }
}

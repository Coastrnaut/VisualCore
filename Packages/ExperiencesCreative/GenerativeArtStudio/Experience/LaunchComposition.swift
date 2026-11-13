// LaunchComposition.swift — DEBUG-only composition data from the launch argument `-gasComposition <base64>` (feature 013
// T-A01-209; clarification 1). Untrusted input: invalid base64 or more than 64 KiB is handed on as corrupt data. Shipping
// builds compile this to nil; Phase 03 replaces it with saved documents and file import.
import Foundation
import GenerativeArtStudioCore

enum LaunchComposition {
    /// The launch data, if any (always nil outside DEBUG).
    static let data: Data? = {
        #if DEBUG
        guard let text = UserDefaults.standard.string(forKey: "gasComposition") else { return nil }
        guard text.utf8.count <= CompositionEditor.maxDataSize * 2, let data = Data(base64Encoded: text) else { return Data("corrupt".utf8) }
        return data
        #else
        return nil
        #endif
    }()

    /// The family to open: the data's family when it names one, else gradient noise (where recovery is shown).
    static var family: SceneFamilyID {
        guard let data, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = object["familyID"] as? String, let id = SceneFamilyID(rawValue: raw) else { return .gradientNoise }
        return id
    }
}

// AppColors.swift — the app's accent (feature 016 T-A01-507): Apple's increased-contrast blues, so tinted text such as
// "Done" and "Export Image" meets text contrast (≥ 4.5:1) in light and dark appearance.
import SwiftUI
import UIKit

enum AppColors {
    /// #0040DD on light backgrounds, #409CFF on dark ones.
    static let accent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x40 / 255.0, green: 0x9C / 255.0, blue: 0xFF / 255.0, alpha: 1)
            : UIColor(red: 0x00 / 255.0, green: 0x40 / 255.0, blue: 0xDD / 255.0, alpha: 1)
    })
}

// HelpTests — feature 140 (A19-P03) T-A19-306 (FR-A19-304; SC-A19-304; clarification Q4). The help has three
// non-empty sections in order, says that the person sets the wallpaper and the app does not, notes that the steps can
// differ between iOS versions, and contains none of the refused phrases (each is spelled in pieces here so the
// repository scans do not match this file).
import Foundation
import Testing
@testable import LivingWallpapersCore

@Suite struct HelpTests {
    /// The refused phrases, assembled from pieces.
    private static let refused = [
        "vid" + "eo", "live wall" + "paper", "set as wall" + "paper", "auto" + "matically",
        "sets your wall" + "paper", "inst" + "alls", "animated wall" + "paper", "sh" + "are", "inst" + "ant",
        "smo" + "oth",
    ]

    @Test func thereAreThreeNonEmptySections() {
        let sections = WallpaperHelp.sections
        #expect(sections.map(\.title) == ["Save the image", "Make it your wallpaper", "Fit the frame"])
        for section in sections {
            #expect(!section.title.isEmpty)
            #expect(!section.body.isEmpty)
        }
    }

    @Test func thePersonSetsTheWallpaper() {
        let body = WallpaperHelp.sections[1].body
        #expect(body.contains("You set the wallpaper yourself"))
        #expect(body.contains("Living Wallpapers does not change it"))
        #expect(body.contains("Settings app"))
        #expect(body.contains("Add New Wallpaper"))
        #expect(body.contains("The steps can differ between iOS versions"))
        #expect(body.contains("the time or widgets"))
        #expect(WallpaperHelp.sections[0].body.contains("Photos"))
    }

    @Test func noRefusedPhraseOrPhaseAppears() {
        for section in WallpaperHelp.sections {
            let text = (section.title + " " + section.body).lowercased()
            for phrase in Self.refused {
                #expect(!text.contains(phrase), "\"\(phrase)\" in \(section.title)")
            }
            #expect(text.range(of: #"a19-p\d|phase"#, options: .regularExpression) == nil, "\(section.title)")
        }
    }
}

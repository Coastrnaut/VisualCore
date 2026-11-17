// WallpaperHelp — feature 140 (A19-P03) T-A19-306 (FR-A19-304; clarification Q4). The three short help sections the
// editor and the export result open: how to keep the image, how the person makes it their wallpaper through the
// Settings app, and what the frame shows. The person does that step; the app never changes it. Pure text.
import Foundation

/// The help text of Living Wallpapers.
public enum WallpaperHelp {
    /// One help section: a title and a body of a few sentences.
    public struct Section: Sendable, Equatable {
        /// The section title.
        public let title: String
        /// The section body.
        public let body: String

        /// Creates a section.
        public init(title: String, body: String) {
            self.title = title
            self.body = body
        }
    }

    /// The three sections, in order: "Save the image", "Make it your wallpaper" and "Fit the frame".
    public static let sections: [Section] = [
        Section(title: "Save the image",
                body: "Export the image at the template's size, then save it to Photos."),
        Section(title: "Make it your wallpaper",
                body: "In the Settings app, choose Wallpaper, then Add New Wallpaper, and pick the image from Photos. "
                    + "The steps can differ between iOS versions. You set the wallpaper yourself; Living Wallpapers "
                    + "does not change it. The system may place the time or widgets over the image."),
        Section(title: "Fit the frame",
                body: "The frame and the shaded bands show the part of the picture the screen shows, and where the "
                    + "time and controls may sit."),
    ]
}

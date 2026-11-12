// AboutView — feature 190 T-U04-011 (FR-U04-054). The about route: the app's name, its version from the bundle
// and the acknowledgements of the shared interface module behind a navigation link.
import SwiftUI
import VisualCoreUI

/// The about page.
struct AboutView: View {
    let model: AppModel

    /// The version of the bundle, for example `1.0.0 (1)`; empty parts are left out.
    static func version(of bundle: Bundle = .main) -> String {
        let short = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return build.isEmpty ? short : "\(short) (\(build))"
    }

    var body: some View {
        List {
            Section {
                Text(AppStrings.text(.appName))
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(AppStrings.text(.aboutSummary))
                    .font(.body)
                Text(AppStrings.text(.aboutVersion, Self.version()))
                    .font(.body)
            }
            Section {
                NavigationLink {
                    AcknowledgementsView()
                } label: {
                    Text(AppStrings.text(.aboutAcknowledgements))
                        .font(.body)
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier(ShellID.aboutAcknowledgements)
            }
        }
        .routeRoot(ShellID.routeAbout)
        .navigationTitle(AppStrings.text(.aboutTitle))
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(AppStrings.text(.navDone)) { model.go(.catalog) }
                    .accessibilityIdentifier(ShellID.navDone)
            }
        }
    }
}

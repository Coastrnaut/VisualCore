// AcknowledgementsView.swift — shows the license texts bundled by scripts/bundle_licenses.py (feature 017 T-A01-610;
// docs/legal/THIRD_PARTY_NOTICES.md: every distributed app bundles and shows them; constitution II: shared by all apps).
import Foundation
import SwiftUI

/// The bundled license index (`Licenses/licenses.json`) and texts.
public struct LicenseInventory: Sendable, Equatable {
    /// One shipped component.
    public struct Entry: Codable, Sendable, Equatable, Identifiable {
        /// Stable id (for example `angle`).
        public let id: String
        /// Display name.
        public let name: String
        /// SPDX-style license expression.
        public let license: String
        /// Text file name inside the folder.
        public let file: String
    }

    /// Components in display order.
    public let entries: [Entry]
    /// The folder that holds the texts.
    public let folder: URL

    /// Loads `licenses.json` from `folder`; nil when it is missing or unreadable.
    public init?(folder: URL) {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("licenses.json")),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return nil }
        self.entries = entries
        self.folder = folder
    }

    /// The bundle's `Licenses` folder (default: the main bundle).
    public init?(bundle: Bundle = .main) {
        guard let url = bundle.resourceURL?.appendingPathComponent("Licenses", isDirectory: true) else { return nil }
        self.init(folder: url)
    }

    /// The full text of `entry`, or an explanation when it cannot be read.
    public func text(for entry: Entry) -> String {
        (try? String(contentsOf: folder.appendingPathComponent(entry.file), encoding: .utf8))
            ?? "The license text for \(entry.name) could not be read."
    }
}

/// A list of the app's third-party components with their licenses; each row opens the full, selectable text.
/// Identifiers: `<prefix>` (list), `<prefix>.<id>` (rows), `<prefix>.text` (text page).
public struct AcknowledgementsView: View {
    let inventory: LicenseInventory?
    let identifierPrefix: String

    /// Shows `inventory` (default: the main bundle's `Licenses` folder).
    public init(inventory: LicenseInventory? = LicenseInventory(), identifierPrefix: String = "vc.acknowledgements") {
        self.inventory = inventory
        self.identifierPrefix = identifierPrefix
    }

    /// The list, or a message when no licenses are bundled.
    public var body: some View {
        Group {
            if let inventory, !inventory.entries.isEmpty {
                List(inventory.entries) { entry in
                    NavigationLink {
                        ScrollView {
                            Text(inventory.text(for: entry))
                                .font(.footnote.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .accessibilityIdentifier("\(identifierPrefix).text")
                        }
                        .navigationTitle(entry.name)
                        .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.name)
                            Text(entry.license).font(.footnote)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    .accessibilityIdentifier("\(identifierPrefix).\(entry.id)")
                }
            } else {
                Text("No license information is bundled with this build.")
                    .padding()
            }
        }
        .navigationTitle("Acknowledgements")
        .accessibilityIdentifier(identifierPrefix)
    }
}

// ExperienceRouteView — feature 190 T-U04-011 (FR-U04-030, FR-U04-031; research R5). The experience route: the
// session's host view for the open experience and one control that closes it and returns to the catalog; the
// notice of a stored state that cannot be read takes the place of the host view (feature 191, FR-U05-031).
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost

/// Shows the session of the app for the experience `id`, with the control that leaves it.
struct ExperienceRouteView: View {
    let model: AppModel
    let id: ExperienceID

    var body: some View {
        VStack(spacing: 0) {
            RouteBackRow(title: AppStrings.text(.experienceBack), identifier: ShellID.experienceBack) {
                model.closeExperience()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            if let notice = model.unreadable, notice.id == id {
                // The stored state cannot be read: nothing runs until the person chooses (feature 191).
                UnreadableStateView(model: model, notice: notice)
            } else {
                ExperienceHostView(session: model.session) { await model.retryExperience() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .routeRoot(ShellID.routeExperience)
        .navigationTitle(model.descriptor(for: id)?.title ?? id.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onChange(of: model.session.state) { _, state in
            // The session's own views (cancel, back after a failure or a message) end in idle: leave the route.
            if state == .idle, model.route == .experience(id), model.unreadable == nil { model.closeExperience() }
        }
    }
}

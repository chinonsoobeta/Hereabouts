import SwiftUI

/// Settings › Send feedback (owner, 13 Nov): written here and sent to support, with no email to write. The name comes
/// first and the page lists exactly what's sent (Apple's rule for optional feedback forms). A failed send keeps the text,
/// and so does a fold or an iPad resize: what's typed is kept by the window, not by this page.
struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WindowState.self) private var ui
    @State private var sending = false
    @State private var problem: String?

    private var ready: Bool {
        !sending && !ui.feedback.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !ui.feedback.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Group { if ui.feedback.sent { thanks } else { form } }
            .navigationTitle("Send feedback").navigationBarTitleDisplayMode(.inline)
    }

    private var form: some View {
        @Bindable var ui = ui
        return SheetForm {
            Section {
                TextField(text: $ui.feedback.name, prompt: Text("First name is fine")) { Text("Your name") }
                    .textContentType(.name).accessibilityIdentifier("feedback.name")
            } header: { Text("Your name") }
            Section {
                TextField(text: $ui.feedback.message, prompt: Text("What's working, what isn't, or what you'd like to see"), axis: .vertical) { Text("Your feedback") }
                    .lineLimit(5...12).accessibilityIdentifier("feedback.message")
            } header: { Text("Your feedback") }
            Section {
                TextField(text: $ui.feedback.email, prompt: Text(verbatim: "you@example.com")) { Text("Your email (optional)") }
                    .keyboardType(.emailAddress).textContentType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityIdentifier("feedback.email")
            } header: { Text("Your email (optional)") }
              footer: { Text("Only if you'd like a reply.").foregroundStyle(Theme.secondary) }
            Section {
                Text("Sent to Hereabouts support: your name, your feedback, your email if you add one, and Hereabouts \(Support.version) on iOS \(UIDevice.current.systemVersion). Nothing from your notebook is sent.")
                    .font(.wbCaption).foregroundStyle(Theme.secondary)
                if let problem { Text(problem).font(.wbBody).foregroundStyle(Theme.amber) }
                Link(destination: Support.mail(subject: "Hereabouts feedback", body: ui.feedback.message)) { Text("Prefer email? Write to \(Support.email)") }
            }
        }
        .groundBackground()
        .onChange(of: ui.feedback.name) { _, value in
            if value.count > Feedback.maximumNameLength { ui.feedback.name = String(value.prefix(Feedback.maximumNameLength)) }
        }
        .safeAreaInset(edge: .bottom) {
            Button { Task { await send() } } label: {
                if sending { ProgressView().tint(.white).accessibilityLabel("Sending") } else { Text("Send") }
            }
            .buttonStyle(PrimaryButtonStyle()).disabled(!ready)
            .accessibilityIdentifier("feedback.send")
            .padding(.horizontal, 20).padding(.vertical, 12).background(Theme.ground)
        }
    }

    private var thanks: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle").font(.system(size: 44)).foregroundStyle(Theme.green).accessibilityHidden(true)
            Text("Thanks. Your feedback was sent.").font(.wbTitle).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
            Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("feedback.done")
        }
        .padding(20).frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.ground)
    }

    private func send() async {
        problem = nil
        do {
            let note = try Feedback.note(name: ui.feedback.name, message: ui.feedback.message, email: ui.feedback.email)
            sending = true
            defer { sending = false }
            try await Feedback.send(note)
            ui.feedback.sent = true
            AccessibilityNotification.Announcement(String(localized: "Thanks. Your feedback was sent.")).post()
        } catch {
            let text = error.plainMessage()
            problem = text
            AccessibilityNotification.Announcement(text).post()
        }
    }
}

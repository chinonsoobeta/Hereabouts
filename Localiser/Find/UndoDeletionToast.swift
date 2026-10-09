import SwiftUI

/// Appears for five seconds after a permanent deletion, with an Undo button.
struct UndoDeletionToast: View {
    @Environment(LocaliserStore.self) private var store
    @State private var error: String?
    var body: some View {
        if let name = store.undoableDeletion {
            HStack(spacing: 12) {
                Text("Deleted \u{201C}\(name)\u{201D}").font(.wbBody).foregroundStyle(Theme.ink).lineLimit(2)
                Spacer(minLength: 8)
                Button("Undo") {
                    do { try store.undoLastDeletion() } catch { self.error = error.localizedDescription }
                }
                .font(.wbItem).foregroundStyle(Theme.purpleInk).frame(minWidth: 44, minHeight: 44)
            }
            .card()
            .padding(.horizontal, 16)
            .padding(.bottom, 64)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: name) {
                AccessibilityNotification.Announcement("Deleted \(name). Undo is available.").post()
                try? await Task.sleep(for: .seconds(5))
                if store.undoableDeletion == name { withAnimation { store.forgetUndo() } }
            }
            .alert("Couldn't undo", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {} message: { Text(error ?? "") }
        }
    }
}

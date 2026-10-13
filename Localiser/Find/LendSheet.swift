import SwiftUI
import ContactsUI

/// "Lend it…": who has it, and when to ask for it back. Only the name is kept.
struct LendSheet: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let item: Belonging
    @State private var person = ""
    @State private var askBack = true
    @State private var day = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
    @State private var picking = false
    @State private var error: String?

    var body: some View {
        SheetForm {
            Section {
                TextField("Who has it?", text: $person).textContentType(.name).accessibilityIdentifier("lend.person")
                Button { picking = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle").font(.system(size: 20)).frame(width: 26).accessibilityHidden(true)
                        Text("Choose from Contacts").font(.wbBody.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Theme.purpleInk)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel("Choose from Contacts")
            } footer: { Text("Only the name is kept. Hereabouts doesn't read your contacts.").foregroundStyle(Theme.secondary) }
            Section {
                Toggle("Remind me to ask for it back", isOn: $askBack)
                if askBack { DatePicker("Ask on", selection: $day, in: Date.now..., displayedComponents: .date) }
            }
        }
        .groundBackground()
        .background(ContactNamePicker(isPresented: $picking) { person = $0 })
        .safeAreaInset(edge: .bottom) {
            Button("Lend it") { save() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(person.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("lend.save")
                .padding(.horizontal, 20).padding(.vertical, 12).background(Theme.ground)
        }
        .navigationTitle("Lend \(item.name)").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        .alert("Couldn't lend it", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    private func save() {
        do {
            try store.lend(item, to: person, askBackOn: askBack ? CalendarDay(day) : nil)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

/// Apple's contact picker runs outside the app, so it needs no Contacts permission.
struct ContactNamePicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var chosen: (String) -> Void

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        context.coordinator.parent = self
        guard isPresented, host.presentedViewController == nil else { return }
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [CNContactGivenNameKey, CNContactFamilyNameKey]
        Task { @MainActor in host.present(picker, animated: true) }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor final class Coordinator: NSObject, @preconcurrency CNContactPickerDelegate {
        var parent: ContactNamePicker
        init(parent: ContactNamePicker) { self.parent = parent }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let name = CNContactFormatter.string(from: contact, style: .fullName) ?? contact.givenName
            if !name.isEmpty { parent.chosen(name) }
            parent.isPresented = false
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.isPresented = false
        }
    }
}

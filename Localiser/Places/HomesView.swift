import SwiftUI

/// "The flat ▾": which home Find, Places and Trips are showing. Only shown once there are two.
struct HomeSwitcher: View {
    @Environment(LocaliserStore.self) private var store
    @State private var managing = false
    var body: some View {
        let _ = store.revision
        if store.hasSeveralHomes, let current = store.currentHome {
            Menu {
                Picker("Home", selection: Binding(get: { current.id }, set: { id in
                    if let home = store.homes.first(where: { $0.id == id }) { store.switchHome(to: home) }
                })) {
                    ForEach(store.homes) { home in Text(home.name).tag(home.id) }
                }
                Divider()
                Button("Manage homes", systemImage: "house.and.flag") { managing = true }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "house").accessibilityHidden(true)
                    Text(current.name).lineLimit(1)
                    Image(systemName: "chevron.down").font(.footnote.weight(.semibold)).accessibilityHidden(true)
                }
                .font(.wbLabel).foregroundStyle(Theme.purpleInk).frame(minHeight: 44)
            }
            .accessibilityLabel("Home").accessibilityValue(current.name).accessibilityIdentifier("home.switcher")
            .sheet(isPresented: $managing) { NavigationStack { HomesView(showsDone: true) } }
        }
    }
}

/// Settings › Homes: rename, add, and remove an empty one.
struct HomesView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(ProAccess.self) private var pro
    @Environment(\.dismiss) private var dismiss
    var showsDone = false
    @State private var renaming: HomeRecord?
    @State private var adding = false
    @State private var name = ""
    @State private var upgrade = false
    @State private var error: String?

    var body: some View {
        let _ = store.revision
        SheetList {
            Section {
                ForEach(store.homes) { home in
                    Button { store.switchHome(to: home) } label: {
                        HStack {
                            NotebookLine(name: home.name, detail: summary(home))
                            Spacer(minLength: 8)
                            if home == store.currentHome { Image(systemName: "checkmark").foregroundStyle(Theme.purpleInk).accessibilityHidden(true) }
                        }.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(home == store.currentHome ? .isSelected : [])
                    .swipeActions {
                        if store.hasSeveralHomes && home.isEmpty {
                            Button("Delete", role: .destructive) { attempt { try store.deleteHome(home) } }
                        }
                        Button("Rename") { name = home.name; renaming = home }.tint(Theme.purpleFill)
                    }
                    .contextMenu {
                        Button("Rename", systemImage: "pencil") { name = home.name; renaming = home }
                        if store.hasSeveralHomes && home.isEmpty {
                            Button("Delete", systemImage: "trash", role: .destructive) { attempt { try store.deleteHome(home) } }
                        }
                    }
                }
            } footer: {
                Text("In Find, Places and Trips, you see your chosen home. Search, dates and reminders cover all homes. You can delete an empty home.")
                    .font(.wbCaption).foregroundStyle(Theme.pencil)
            }
        }
        .listStyle(.plain)
        .font(.wbBody).tint(Theme.purpleInk).groundBackground()
        .navigationTitle("Homes").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDone { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
            ToolbarItem(placement: .primaryAction) {
                Button("Add a home", systemImage: "plus") {
                    guard pro.allows(.home, count: store.homes.count) else { upgrade = true; return }
                    name = ""; adding = true
                }.accessibilityIdentifier("home.add")
            }
        }
        .alert("New home", isPresented: $adding) {
            TextField("Mom's house", text: $name).accessibilityIdentifier("home.name")
            Button("Cancel", role: .cancel) {}
            Button("Add") { attempt { try store.addHome(name: name) } }
        } message: { Text("You can add a parent's home, a storage unit or a boat.") }
        .alert("Rename home", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $name)
            Button("Cancel", role: .cancel) { renaming = nil }
            Button("Save") { if let home = renaming { attempt { try store.renameHome(home, to: name) } }; renaming = nil }
        }
        .sheet(isPresented: $upgrade) { NavigationStack { ProView() } }
        .alert("Couldn't change that", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    private func summary(_ home: HomeRecord) -> String {
        let places = home.places.filter { $0.parent == nil }.count
        let things = home.items.filter { !$0.archived }.count
        if places == 0 && things == 0 { return String(localized: "Empty") }
        return "\(String(localized: "\(places) rooms")) · \(String(localized: "\(things) things"))"
    }

    private func attempt(_ work: () throws -> Void) {
        do { try work() } catch { self.error = error.localizedDescription }
    }
}

/// "Move to another home": pick a home, then a place in it or its top level. Moves a thing, or a place with
/// everything inside it.
struct MoveToHomeSheet: View {
    enum Subject { case thing(Belonging), place(Place) }
    @Environment(LocaliserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let subject: Subject
    @State private var error: String?

    private var currentHome: HomeRecord? {
        switch subject { case .thing(let item): item.home; case .place(let place): place.home }
    }

    var body: some View {
        let _ = store.revision
        SheetList {
            Section {
                ForEach(store.homes.filter { $0 != currentHome }) { home in
                    NavigationLink {
                        PlaceChooser(selection: Binding(get: { nil }, set: { id in move(to: home, place: store.places.first { $0.id == id }) }),
                                     noneTitle: String(localized: "Top level"), title: String(localized: "Where in \(home.name)?"), home: home)
                    } label: { NotebookLine(name: home.name, detail: "") }
                }
            } footer: {
                Text(footer).font(.wbCaption).foregroundStyle(Theme.pencil)
            }
        }
        .listStyle(.plain)
        .font(.wbBody).tint(Theme.purpleInk).groundBackground()
        .navigationTitle("Move to another home").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        .alert("Couldn't move that", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    private var footer: String {
        switch subject {
        case .thing: String(localized: "Choose a home, then a place in it.")
        case .place: String(localized: "You also move every place and thing inside it.")
        }
    }

    private func move(to home: HomeRecord, place: Place?) {
        do {
            switch subject {
            case .thing(let item): try store.moveThing(item, toHome: home, place: place)
            case .place(let moving): try store.movePlace(moving, toHome: home, under: place)
            }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

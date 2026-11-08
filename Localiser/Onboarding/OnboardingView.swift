import SwiftUI

/// The name of the current home, kept for onboarding and as a fallback. A notebook can hold several homes; see Data/Homes.swift.
enum Home {
    static let nameKey = "homeName"
    static let defaultName = String(localized: "Home")
    /// Long enough for "Grandma's cottage by the sea", short enough for the Find subtitle.
    static let maxLength = 40
    static var name: String {
        let stored = UserDefaults.standard.string(forKey: nameKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return stored.isEmpty ? defaultName : stored
    }
}

/// Three pages on first launch, from the design canvas. Replayable from Settings.
struct OnboardingView: View {
    static let seenKey = "onboardingSeen"
    var onFinish: () -> Void
    @Environment(LocaliserStore.self) private var store
    @Environment(ReminderService.self) private var reminders
    @Environment(ProAccess.self) private var pro
    @AppStorage(Home.nameKey) private var homeName = ""
    @State private var page = 0
    /// Which way the pages slide: forward pushes the current page out to the left.
    @State private var forward = true
    @State private var thing = String(localized: "Spare keys")
    @State private var room = ""
    @State private var error: String?
    /// The thing written down on page 2. Going back and writing again edits it rather than adding another.
    @State private var written: Belonging?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if page == 0 {
                    Text("Hereabouts").font(.wbCaption).foregroundStyle(Theme.pencil).fixedSize().layoutPriority(1)
                } else {
                    Button { go(to: page - 1) } label: { Label("Back", systemImage: "chevron.left") }
                        .font(.wbBody).foregroundStyle(Theme.ink).frame(minHeight: 44)
                }
                Spacer()
                Text("Page \(page + 1) of 3").font(.wbCaption).foregroundStyle(Theme.pencil).multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 24).padding(.top, 8)
            ZStack {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            switch page {
                            case 0: namePage
                            case 1: thingPage
                            default: nudgePage
                            }
                        }
                        .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    VStack(spacing: 10) { actions }.padding(.horizontal, 24).padding(.bottom, 16)
                }
                .background(Theme.paper)
                .id(page)
                .transition(.asymmetric(insertion: .move(edge: forward ? .trailing : .leading), removal: .move(edge: forward ? .leading : .trailing)))
            }
            .clipped()
        }
        .background(Theme.paper)
        .alert("Couldn't write that down", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    // MARK: Pages

    @ViewBuilder private var namePage: some View {
        headline(String(localized: "Your notebook for things at home."))
        Text("Write down where you keep things, and find them later. Your notebook is saved on this iPhone so you don't need an account.").font(.wbBody).foregroundStyle(Theme.ink)
        Text("What do you call home?").font(.wbLabel).textCase(.uppercase).tracking(1.76).foregroundStyle(Theme.pencil).padding(.top, 10)
        underlinedField(String(localized: "My apartment"), text: $homeName).accessibilityLabel(String(localized: "What do you call home?"))
            .onChange(of: homeName) { _, name in if name.count > Home.maxLength { homeName = String(name.prefix(Home.maxLength)) } }
        suggestions([String(localized: "My apartment"), String(localized: "Home"), String(localized: "Mom's house"), String(localized: "The boat")], selected: homeName) { homeName = $0 }
    }

    @ViewBuilder private var thingPage: some View {
        headline(String(localized: "What do you often look for?"))
        Text("Choose a thing or type your own. Add it to your notebook.").font(.wbBody).foregroundStyle(Theme.ink)
        suggestions([String(localized: "Spare keys"), String(localized: "Passport"), String(localized: "Charger"), String(localized: "Sunglasses"), String(localized: "The drill"), String(localized: "Tape measure")], selected: thing) { thing = $0 }
        underlinedField(String(localized: "Spare keys"), text: $thing).accessibilityLabel(String(localized: "Thing you often look for"))
        underlinedField(String(localized: "Kitchen"), text: $room).accessibilityLabel(String(localized: "Where do you keep it?")).padding(.top, 10)
        Text("Where do you keep it?").font(.wbLabel).textCase(.uppercase).tracking(1.76).foregroundStyle(Theme.pencil).accessibilityHidden(true)
    }

    @ViewBuilder private var nudgePage: some View {
        headline(String(localized: "Reminders when you need them."))
        Text("You only get reminders about your own things. Nothing else, ever.").font(.wbBody).foregroundStyle(Theme.ink)
        VStack(spacing: 0) {
            nudge(String(localized: "Lent"), String(localized: "On the day you choose to ask for it back"))
            nudge(String(localized: "Trip"), String(localized: "The evening before you leave, if something's unpacked"))
            nudge(String(localized: "Sunday"), String(localized: "What you added, lent out or haven't checked lately"))
            nudge(String(localized: "Monthly"), String(localized: "Still there? A few quick questions on the first Saturday"))
        }
        .overlay(alignment: .top) { Rectangle().fill(Theme.ink).frame(height: 1.5) }
        StickyNote {
            VStack(alignment: .leading, spacing: 6) {
                Text("“Ask Sam for Drill back.”").font(.wbQuote).foregroundStyle(Theme.ink)
                Text("You can hide names in reminders in Settings.").font(.wbCaption).foregroundStyle(Theme.ink)
            }
        }
        Text("You can also ask Siri where things are.").font(.wbCaption).foregroundStyle(Theme.pencil)
    }

    @ViewBuilder private var actions: some View {
        switch page {
        case 0:
            Button {
                focused = false; homeName = homeName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !homeName.isEmpty, let home = store.currentHome { try? store.renameHome(home, to: homeName) }
                go(to: 1)
            } label: { wrapping(String(localized: "Open your notebook")) }
                .buttonStyle(PrimaryButtonStyle())
            Text("You can rename it any time in Settings.").font(.wbCaption).foregroundStyle(Theme.pencil).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity)
        case 1:
            Button { writeItDown() } label: { wrapping(String(localized: "Write it down")) }
                .buttonStyle(PrimaryButtonStyle()).disabled(thing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("I'll do this later") { focused = false; go(to: 2) }
                .font(.wbBody).foregroundStyle(Theme.pencil).frame(minHeight: 44)
        default:
            Button { Task { await reminders.enable(); onFinish() } } label: { wrapping(String(localized: "Turn on reminders")) }
                .buttonStyle(PrimaryButtonStyle())
            Button("Not now") { onFinish() }.font(.wbBody).foregroundStyle(Theme.pencil).frame(minHeight: 44)
            Text("You can change this in Settings any time.").font(.wbCaption).foregroundStyle(Theme.pencil).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity)
        }
    }

    // MARK: Pieces

    /// Slides to another page. The direction is set first, on its own, so the page leaving uses it too.
    private func go(to target: Int) {
        forward = target > page
        Task { @MainActor in withAnimation(.easeInOut(duration: 0.35)) { page = target } }
    }

    private func wrapping(_ title: String) -> some View {
        Text(title).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
    }

    private func headline(_ text: String) -> some View {
        Text(text).font(.wbDisplay).foregroundStyle(Theme.ink).accessibilityAddTraits(.isHeader).fixedSize(horizontal: false, vertical: true)
    }

    private func underlinedField(_ prompt: String, text: Binding<String>) -> some View {
        TextField(prompt, text: text)
            .font(.wbItem).foregroundStyle(Theme.ink).focused($focused).submitLabel(.done)
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.ink).frame(height: 1.5) }
    }

    private func suggestions(_ options: [String], selected: String, choose: @escaping (String) -> Void) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                let on = option.localizedCaseInsensitiveCompare(selected) == .orderedSame
                Button(option) { choose(option) }
                    .font(.wbBody).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).frame(minHeight: 44)
                    .background(on ? Theme.highlighter : Color.clear, in: RoundedRectangle(cornerRadius: 3))
                    .overlay { RoundedRectangle(cornerRadius: 3).stroke(on ? Theme.ink : Theme.rule, lineWidth: on ? 1.5 : 1) }
                    .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    private func nudge(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.wbItem).foregroundStyle(Theme.ink)
            Text(detail).font(.wbCaption).foregroundStyle(Theme.pencil).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }

    /// Why the introduction can't write the thing down, or nil when it can.
    static func refusal(rewriting: Bool, allowed: Bool) -> String? {
        rewriting || allowed ? nil : ItemEditor.freePlanFull
    }

    private func writeItDown() {
        focused = false
        let rewriting = written.map { $0.managedObjectContext != nil && !$0.isDeleted } ?? false
        // Replaying the introduction never adds past the free allowance, and says why.
        if let refusal = Self.refusal(rewriting: rewriting, allowed: pro.allows(.item, count: store.activeItemCount)) {
            go(to: 2); error = refusal; return
        }
        do {
            let roomName = room.trimmingCharacters(in: .whitespacesAndNewlines)
            var place: Place?
            if !roomName.isEmpty { place = try store.duplicatePlace(named: roomName, parent: nil) ?? store.addPlace(name: roomName) }
            if rewriting, let written {
                try store.editItem(written, name: thing, place: place, notes: written.notes, aliases: written.aliases, photo: written.photo)
            } else {
                written = try store.addItem(name: thing, place: place)
            }
            go(to: 2)
        } catch { self.error = error.localizedDescription }
    }
}

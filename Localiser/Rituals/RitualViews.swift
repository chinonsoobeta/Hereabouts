import SwiftUI

enum Ritual: String, Identifiable {
    case recap, stocktake
    var id: String { rawValue }
}

/// The Sunday recap sheet from the canvas: the last seven days, the next seven, and what's drifting.
struct RecapView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Home.nameKey) private var homeName = ""
    @AppStorage(Rituals.recapReadKey) private var readWeek = ""
    var seeDue: () -> Void = {}
    var startStocktake: () -> Void = {}

    var body: some View {
        let _ = store.revision
        let recap = Rituals.recap(items: store.items, deadlines: store.deadlines)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.wbCaption).foregroundStyle(Theme.pencil)
                HStack(alignment: .top) {
                    Text("This week at \(homeName.isEmpty ? "home" : homeName.lowercasedFirstArticle)").font(.wbDisplay).foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    if recap.keepingUp > 0 { Stamp(text: recap.keepingUp == 1 ? "1 week" : "\(recap.keepingUp) weeks", tone: .purple) }
                }
                Text(keepingUpSentence(recap.keepingUp)).font(.wbBody).foregroundStyle(Theme.ink)
                VStack(spacing: 0) {
                    figure(recap.added.count, recap.added.count == 1 ? "new thing written down" : "new things written down", recap.added.isEmpty ? "Nothing new this week. That's fine." : ListFormatter.localizedString(byJoining: Array(recap.added.prefix(4))))
                    figure(recap.moved, recap.moved == 1 ? "thing moved or put away" : "things moved or put away", nil)
                    figure(recap.confirmed, recap.confirmed == 1 ? "thing checked and still there" : "things checked and still there", nil)
                }
                .overlay(alignment: .top) { Rectangle().fill(Theme.ink).frame(height: 1.5) }
                SectionHeading(title: "Next week").padding(.top, 6)
                VStack(spacing: 0) {
                    if recap.due.isEmpty { line("Nothing due", "") }
                    ForEach(recap.due.prefix(5)) { deadline in
                        line(deadline.item?.name ?? "A saved thing", dueDetail(deadline))
                    }
                    if recap.stocktakeCount > 0 {
                        line("Stocktake", recap.stocktakeCount == 1 ? "1 quick question" : "\(recap.stocktakeCount) quick questions")
                    }
                }
                if !recap.drifting.isEmpty {
                    SectionHeading(title: "Drifting").padding(.top, 6)
                    VStack(spacing: 0) {
                        ForEach(recap.drifting) { item in line(item.name, "not checked since \(item.lastConfirmed.formatted(.dateTime.month(.wide).year()))") }
                    }
                }
                VStack(spacing: 10) {
                    if recap.stocktakeCount > 0 {
                        Button { dismiss(); startStocktake() } label: { Text("Start the stocktake").fixedSize(horizontal: false, vertical: true) }.buttonStyle(PrimaryButtonStyle())
                    }
                    if !recap.due.isEmpty {
                        Button { dismiss(); seeDue() } label: { Text("See what's due").fixedSize(horizontal: false, vertical: true) }.buttonStyle(SoftButtonStyle())
                    }
                }.padding(.top, 8)
                Text("Recaps can be turned off in Settings.").font(.wbCaption).foregroundStyle(Theme.pencil).frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .background(Theme.paper)
        .onAppear { readWeek = Rituals.recapWeekKey() }
        .navigationTitle("Recap").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }

    private func dueDetail(_ deadline: Deadline) -> String {
        let verb: String
        switch deadline.kind {
        case .returns: verb = "Return by"
        case .warranty: verb = "Warranty ends"
        case .expiry: verb = "Expires"
        case nil: verb = "Due"
        }
        return verb + " " + (deadline.day?.formatted ?? "")
    }

    private func keepingUpSentence(_ weeks: Int) -> String {
        switch weeks {
        case 0: "Write one thing down this week to start keeping up."
        case 1: "Keeping up: something written down this week."
        default: "Keeping up: \(weeks) weeks in a row with something written down."
        }
    }

    private func figure(_ number: Int, _ label: String, _ detail: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(number.formatted()).font(.wbTitle).foregroundStyle(Theme.purpleInk).frame(minWidth: 36, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.wbBody).foregroundStyle(Theme.ink)
                if let detail { Text(detail).font(.wbCaption).foregroundStyle(Theme.pencil) }
            }.fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }

    private func line(_ name: String, _ detail: String) -> some View {
        NotebookLine(name: name, detail: detail)
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
    }
}

/// "Still there?" cards, five at a time, once a month.
struct StocktakeView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Rituals.stocktakeDoneKey) private var doneMonth = ""
    @State private var queue: [Belonging] = []
    @State private var answered = 0
    @State private var total = 0
    @State private var moving: Belonging?
    @State private var lastArchived: Belonging?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Still there?").font(.wbDisplay).foregroundStyle(Theme.ink).accessibilityAddTraits(.isHeader)
                if let item = queue.first {
                    Text("A few quick questions once a month keep the notebook honest. Nothing changes unless you say so.").font(.wbBody).foregroundStyle(Theme.ink)
                    progress
                    card(item)
                    HStack(spacing: 10) {
                        Button { answer { try store.confirm(item) } } label: { Label("Still there", systemImage: "checkmark") }
                            .buttonStyle(PrimaryButtonStyle())
                        Button { moving = item } label: { Label("Moved", systemImage: "pencil") }
                            .buttonStyle(SoftButtonStyle())
                    }
                    Button("Don't have it any more") { answer { try store.setArchived(item, true); lastArchived = item } }
                        .font(.wbBody).foregroundStyle(Theme.pencil).frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Text(total == 0 ? "Everything has been checked recently. Nothing to ask this month." : "All checked. The notebook's up to date. See you next month.")
                        .font(.wbBody).foregroundStyle(Theme.ink)
                    Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle())
                }
                if let lastArchived, !lastArchived.isDeleted, lastArchived.archived {
                    Button("Undo: keep \(lastArchived.name)") {
                        do { try store.setArchived(lastArchived, false); self.lastArchived = nil } catch { self.error = error.localizedDescription }
                    }.font(.wbCaption).foregroundStyle(Theme.purpleInk).frame(minHeight: 44)
                }
            }
            .padding(20)
        }
        .background(Theme.lilacPaper)
        .navigationTitle("Stocktake · \(Date.now.formatted(.dateTime.month(.wide)))").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Later") { dismiss() } } }
        .onAppear {
            guard total == 0 else { return }
            queue = Rituals.stocktake(store.items); total = queue.count
            if total == 0 { doneMonth = Rituals.monthKey(.now) }
        }
        .sheet(item: $moving) { item in
            NavigationStack {
                PlaceChooser(selection: Binding(get: { item.place?.id }, set: { id in
                    answer { try store.move(item, to: store.places.first { $0.id == id }) }
                }))
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { moving = nil } } }
            }
        }
        .alert("Couldn't update", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    private var progress: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(0..<total, id: \.self) { index in
                    Circle().fill(index < answered ? Theme.purpleInk : Theme.paper)
                        .overlay { Circle().stroke(index < answered ? Theme.purpleInk : Theme.ink, lineWidth: 1.5) }
                        .frame(width: 10, height: 10)
                }
            }.accessibilityHidden(true)
            Text("\(answered + 1) of \(total)").font(.wbCaption).foregroundStyle(Theme.ink).padding(.leading, 6)
                .accessibilityLabel("Question \(answered + 1) of \(total)")
        }
    }

    private func card(_ item: Belonging) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Stamp(text: monthsAgo(item.lastConfirmed), tone: .due)
            Text(item.name).font(.wbDisplay).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("lives in").font(.wbBody).foregroundStyle(Theme.pencil)
                PlaceBreadcrumb(path: item.place?.path)
            }
            Text("Last checked \(item.lastConfirmed.dayAndMonth). Is it still there?").font(.wbCaption).foregroundStyle(Theme.ink)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(Theme.ink, lineWidth: 1.5) }
        .background {
            RoundedRectangle(cornerRadius: 8).fill(Theme.paper).overlay { RoundedRectangle(cornerRadius: 8).stroke(Theme.ink, lineWidth: 1.5) }
                .rotationEffect(.degrees(-2)).offset(y: 8).accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    private func monthsAgo(_ date: Date) -> String {
        let months = Calendar.current.dateComponents([.month], from: date, to: .now).month ?? 0
        return months <= 1 ? "A while ago" : "\(months) months ago"
    }

    private func answer(_ change: () throws -> Void) {
        do {
            try change()
            moving = nil
            if !queue.isEmpty { queue.removeFirst() }
            answered += 1
            if queue.isEmpty { doneMonth = Rituals.monthKey(.now) }
        } catch { self.error = error.localizedDescription }
    }
}

/// Find's header notes: keeping up and, once a month, the stocktake.
struct RitualBanners: View {
    @Environment(LocaliserStore.self) private var store
    @AppStorage(Rituals.stocktakeDoneKey) private var doneMonth = ""
    @AppStorage(Rituals.recapKey) private var recapOn = true
    @AppStorage(Rituals.recapReadKey) private var readWeek = ""
    var open: (Ritual) -> Void

    var body: some View {
        let _ = store.revision
        let weeks = Rituals.keepingUpWeeks(activity: Rituals.activity(in: store.items))
        let stamp: String? = weeks > 0 ? (weeks == 1 ? "1 week" : "\(weeks) weeks") : nil
        let recapReady = recapOn && readWeek != Rituals.recapWeekKey()
        let stocktake = Rituals.stocktakeDue(store.items, doneMonth: doneMonth)
        VStack(alignment: .leading, spacing: 10) {
            if recapReady {
                banner(stamp: stamp, text: weeks > 0 ? "Keeping up. Sunday's recap is ready." : "Sunday's recap is ready.", action: "Read it") { open(.recap) }
            } else if let stamp {
                HStack(spacing: 12) {
                    Stamp(text: stamp, tone: .purple)
                    Text("Keeping up.").font(.wbBody).foregroundStyle(Theme.ink)
                }
                .padding(.vertical, 4).accessibilityElement(children: .combine)
            }
            if stocktake {
                banner(stamp: nil, text: "Still there? A few things haven't been checked in a while.", action: "Start") { open(.stocktake) }
            }
        }
    }

    @Environment(\.dynamicTypeSize) private var textSize

    private func banner(stamp: String?, text: String, action: String, perform: @escaping () -> Void) -> some View {
        let layout = textSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        return layout {
            if let stamp { Stamp(text: stamp, tone: .purple) }
            Text(text).font(.wbBody).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
            if !textSize.isAccessibilitySize { Spacer(minLength: 0) }
            Button(action, action: perform).font(.wbBody.weight(.bold)).foregroundStyle(Theme.purpleInk).frame(minWidth: 44, minHeight: 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 4)
        .background(Theme.noteBox, in: RoundedRectangle(cornerRadius: 6))
        .overlay { RoundedRectangle(cornerRadius: 6).stroke(Theme.ink, lineWidth: 1.5) }
    }
}

/// On a thing's page: "Still in Garage › Shelf 4, as of Tuesday. Is it?"
struct StillThereRow: View {
    @Environment(LocaliserStore.self) private var store
    let item: Belonging
    var move: () -> Void
    @State private var error: String?

    var body: some View {
        // Only asks once a thing hasn't been looked at for a fortnight; otherwise the moved line says enough.
        let recent = item.lastConfirmed > Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        VStack(alignment: .leading, spacing: 10) {
            if !recent {
                Text("Last checked \(item.lastConfirmed.dayAndMonth). Is it still there?")
                    .font(.wbCaption).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button("Still there") {
                        do { try store.confirm(item) } catch { self.error = error.localizedDescription }
                    }.buttonStyle(SoftButtonStyle(compact: true)).accessibilityIdentifier("item.stillThere")
                    Button("Moved", action: move).buttonStyle(SoftButtonStyle(compact: true))
                }
            }
        }
        .alert("Couldn't update", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
}

extension String {
    /// "The flat" reads as "the flat" mid-sentence; "Mum's house" stays as written.
    var lowercasedFirstArticle: String {
        for article in ["The ", "A ", "An "] where hasPrefix(article) { return article.lowercased() + dropFirst(article.count) }
        return self
    }
}

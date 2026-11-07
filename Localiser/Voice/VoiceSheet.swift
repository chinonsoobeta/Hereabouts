import SwiftUI

/// A place the person said that the notebook doesn't have yet, offered as "New place: <words>".
struct SpokenPlace: Equatable {
    var name: String
    /// The existing place it would go inside, when the rest of what was said matched one.
    var parentID: UUID?
}

/// Hold the microphone and say where something is. What was heard can be corrected by typing, and
/// nothing is saved here: Continue opens the usual new-thing screen, filled in.
struct VoiceSheet: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var capture = VoiceCapture()
    @State private var text = ""
    @State private var pressStart: Date?
    @State private var wasListening = false
    @State private var noSplit = false
    /// Called with the name, the matched place and any new place before the sheet closes.
    let onResult: (NewThing) -> Void

    var body: some View {
        SheetForm {
            Section {
                TextField("The spare key's in the blue tin on the hall shelf", text: $text, axis: .vertical)
                    .lineLimit(2...5).accessibilityIdentifier("voice.text")
                if let message = capture.message { Text(message).font(.wbCaption).foregroundStyle(Theme.warning) }
                if noSplit { Text("Say what it is and where, such as \u{201C}the drill's in the garage\u{201D}.").font(.wbCaption).foregroundStyle(Theme.secondary) }
            } header: { Text("What did you put away?").font(.wbLabel).foregroundStyle(Theme.ink).textCase(nil) }
              footer: { Text("Hold the button and talk, or tap it to start and stop. Nothing is recorded.").foregroundStyle(Theme.secondary) }
            Section { microphone.frame(maxWidth: .infinity) }.listRowBackground(Color.clear)
        }
        .groundBackground()
        .safeAreaInset(edge: .bottom) {
            Button("Continue") { finish() }
                .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("voice.continue")
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || capture.phase != .idle)
                .padding(.horizontal, 20).padding(.vertical, 12).background(Theme.ground)
        }
        .navigationTitle("Say where").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { Task { await capture.stop(); dismiss() } } } }
        .onChange(of: capture.transcript) { _, heard in if !heard.isEmpty { text = heard } }
        .onDisappear { Task { await capture.stop() } }
    }

    private var listening: Bool { capture.phase == .listening || capture.phase == .preparing }

    private var microphone: some View {
        Image(systemName: listening ? "waveform" : "mic.fill")
            .font(.system(size: 34, weight: .semibold)).foregroundStyle(.white)
            .frame(width: 88, height: 88)
            .background(listening ? Theme.warning : Theme.purpleFill, in: Circle())
            .symbolEffect(.variableColor.iterative, isActive: capture.phase == .listening)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard pressStart == nil else { return }
                    pressStart = .now
                    wasListening = listening
                    if !wasListening { Task { await capture.start() } }
                }
                .onEnded { _ in
                    // A long hold stops on release; a short tap leaves it listening until the next tap.
                    let held = pressStart.map { Date.now.timeIntervalSince($0) } ?? 0
                    pressStart = nil
                    if wasListening || held > 0.5 { Task { await capture.stop() } }
                })
            .accessibilityElement()
            .accessibilityLabel(listening ? "Stop listening" : "Start listening")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { Task { if listening { await capture.stop() } else { await capture.start() } } }
            .accessibilityIdentifier("voice.microphone")
    }


    private func finish() {
        let places = store.placesHere.map { VoiceParser.Candidate(id: $0.id, path: $0.path.components(separatedBy: " › ")) }
        let sentence = text
        Task {
            guard let result = await VoiceUnderstanding.understand(sentence, places: places) else { noSplit = true; return }
            let spoken = result.placeID == nil ? result.newPlaceName.map { SpokenPlace(name: $0, parentID: result.newPlaceParent) } : nil
            onResult(NewThing(name: result.name, placeID: result.placeID, spokenPlace: spoken))
            dismiss()
        }
    }
}

/// Under the place picker on the new-thing screen: one tap makes the place the person said.
struct NewPlaceSuggestion: View {
    @Environment(LocaliserStore.self) private var store
    let spoken: SpokenPlace
    let made: (UUID) -> Void
    @State private var error: String?

    var body: some View {
        let parent = spoken.parentID.flatMap { id in store.places.first { $0.id == id } }
        Button {
            do { made(try store.addPlace(name: spoken.name, parent: parent).id) } catch { self.error = error.localizedDescription }
        } label: {
            Label(parent.map { "New place: \(spoken.name) in \($0.name)" } ?? "New place: \(spoken.name)", systemImage: "plus.circle")
        }
        .accessibilityIdentifier("voice.newPlace")
        if let error { Text(error).font(.wbCaption).foregroundStyle(Theme.warning) }
    }
}

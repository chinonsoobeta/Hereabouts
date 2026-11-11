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
    /// True while a finger is on the microphone.
    @State private var holding = false
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
              footer: { Text("Hold the button while you talk, and let go when you're done. Nothing is recorded.").foregroundStyle(Theme.secondary) }
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
                    guard !holding else { return }
                    holding = true
                    // Letting go before listening has started (the first time asks for the microphone) stops it as soon as it starts.
                    Task { await capture.start(); if !holding { await capture.stop() } }
                }
                .onEnded { _ in
                    // Listening lasts only while the button is held.
                    holding = false
                    if capture.phase == .listening { Task { await capture.stop() } }
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
            do { made(try store.addPlace(name: spoken.name, parent: parent).id) } catch { self.error = error.plainMessage() }
        } label: {
            Label(parent.map { "New place: \(spoken.name) in \($0.name)" } ?? "New place: \(spoken.name)", systemImage: "plus.circle")
        }
        .accessibilityIdentifier("voice.newPlace")
        if let error { Text(error).font(.wbCaption).foregroundStyle(Theme.warning) }
    }
}

import MessageUI
import SwiftUI

/// "Text them" (the owner's yes, 12 Nov): a note asking for a lent thing back, opened in Messages for the lender to send.
/// The lender picks who it goes to in Messages' own To field, so Hereabouts never asks for or keeps a phone number.
enum AskBackNote {
    static func text(person: String, thing: String) -> String {
        String(localized: "Hi \(person), could I have my \(thing) back when you get a chance?")
    }

    /// The thing keeps its name even when it's private: the lender reads the note before sending it.
    static func text(for item: Belonging) -> String { text(person: item.lentTo, thing: item.name) }

    /// Whether this device can send a text. Without Messages, the thing page shares the note instead, and reminders have no button.
    static var canText: Bool { MFMessageComposeViewController.canSendText() }
}

/// A note waiting to open in Messages.
struct AskBackText: Identifiable, Hashable {
    let id = UUID()
    let body: String
}

/// Messages' own compose sheet, with the note written and the To field left for the lender.
struct MessageComposer: UIViewControllerRepresentable {
    let body: String
    let done: () -> Void

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let composer = MFMessageComposeViewController()
        composer.body = body
        composer.messageComposeDelegate = context.coordinator
        return composer
    }

    func updateUIViewController(_ composer: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(done: done) }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let done: () -> Void
        init(done: @escaping () -> Void) { self.done = done }
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) { done() }
    }
}

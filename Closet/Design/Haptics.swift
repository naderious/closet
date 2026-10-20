import UIKit

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.75)
    }

    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func rigid() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.8)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

//
//  NotificationDelegate.swift
//  stts
//

import MBPopup
import UserNotifications

// Deliberately not `@MainActor`: `UNUserNotificationCenterDelegate`'s requirements aren't
// actor-isolated, so a non-isolated class satisfies them without needing `@preconcurrency` to
// paper over a mismatch. The one requirement that touches UI (`didReceive`) hops to the main
// actor itself for just that call, instead of isolating the whole delegate.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let popupController: MBPopupController

    init(popupController: MBPopupController) {
        self.popupController = popupController
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor [popupController] in
            popupController.openPopup()
        }
        completionHandler()
    }
}

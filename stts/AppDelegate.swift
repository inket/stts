//
//  AppDelegate.swift
//  stts
//

import Cocoa
import MBPopup
import Reachability

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var timer: Timer?

    let reachability = try! Reachability() // swiftlint:disable:this force_try

    let popupController: MBPopupController
    let serviceTableViewController = ServiceTableViewController()
    let editorTableViewController: EditorTableViewController

    override init() {
        self.popupController = MBPopupController(contentView: serviceTableViewController.contentView)
        self.editorTableViewController = serviceTableViewController.editorTableViewController
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(AppDelegate.restartTimer),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        reachability.whenReachable = { _ in self.updateServices() }
        reachability.whenUnreachable = { _ in self.updateServices() }

        try? reachability.startNotifier()

        if #available(OSX 10.14, *) {
            Appearance.addObserver(self)
        } else {
            popupController.backgroundView.backgroundColor = .white
        }

        NSUserNotificationCenter.default.delegate = self

        popupController.statusItem.button?.title = "stts"
        popupController.statusItem.button?.font =
            NSFont(name: "SF Mono Regular", size: 10) ?? NSFont.systemFont(ofSize: 12)
        popupController.statusItem.length = 30

        popupController.contentView.wantsLayer = true
        popupController.contentView.layer?.masksToBounds = true

        serviceTableViewController.setup()

        popupController.willOpenPopup = { [weak self] _ in
            if self?.editorTableViewController.hidden == true {
                self?.serviceTableViewController.willOpenPopup()
            } else {
                self?.editorTableViewController.willOpenPopup()
            }
        }

        popupController.didOpenPopup = { [weak self] in
            if self?.editorTableViewController.hidden == false {
                self?.editorTableViewController.didOpenPopup()
            }
        }

        restartTimer()
    }

    @objc func restartTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: 300,
            target: self,
            selector: #selector(AppDelegate.updateServices),
            userInfo: nil,
            repeats: true
        )
        timer?.fire()
    }

    @objc func updateServices() {
        serviceTableViewController.updateServices { [weak self] in
            let title = self?.serviceTableViewController.generalStatus == .major ? "s__s" : "stts"
            self?.popupController.statusItem.title = title

            if Preferences.shared.notifyOnStatusChange {
                self?.serviceTableViewController.services.forEach { $0.notifyIfNecessary() }
            }
        }
    }
}

extension AppDelegate: NSUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        popupController.openPopup()
    }
}

extension AppDelegate: AppearanceObserver {
    func changeAppearance(to newAppearance: NSAppearance) {
        popupController.backgroundView.backgroundColor = newAppearance.isDarkMode ? .windowBackgroundColor : .white
    }
}

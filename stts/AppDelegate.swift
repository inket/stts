//
//  AppDelegate.swift
//  stts
//

import Cocoa
import MBPopup
import SnapKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var timer: Timer?

    let popupController: MBPopupController
    let serviceTableViewController = ServiceTableViewController()
    let editorTableViewController: EditorTableViewController

    override init() {
        self.popupController = MBPopupController(contentView: serviceTableViewController.contentView)
        self.editorTableViewController = serviceTableViewController.editorTableViewController
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSUserNotificationCenter.default.delegate = self

        popupController.statusItem.button?.title = "stts"
        popupController.statusItem.button?.font = NSFont(name: "SF Mono Regular", size: 10) ?? NSFont.systemFont(ofSize: 12)
        popupController.statusItem.length = 30

        popupController.backgroundView.backgroundColor = NSColor.white
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

        popupController.didOpenPopup = { [weak self] _ in
            if self?.editorTableViewController.hidden == false {
                self?.editorTableViewController.didOpenPopup()
            }
        }

        self.timer = Timer.scheduledTimer(timeInterval: 300,
                                          target: self,
                                          selector: #selector(AppDelegate.updateServices),
                                          userInfo: nil,
                                          repeats: true)
        timer?.fire()
    }

    func updateServices() {
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

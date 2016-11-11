//
//  AppDelegate.swift
//  stts
//
//  Created by inket on 28/7/16.
//  Copyright © 2016 inket. All rights reserved.
//

import Cocoa
import MBPopup
import SnapKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var timer: Timer?

    let popupController: MBPopupController
    let serviceTableViewController = ServiceTableViewController()

    override init() {
        self.popupController = MBPopupController(contentView: serviceTableViewController.contentView)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        popupController.statusItem.button?.title = "stts"
        popupController.statusItem.button?.font = NSFont(name: "SF Mono Regular", size: 10)
        popupController.statusItem.length = 30

        popupController.contentView.wantsLayer = true
        popupController.contentView.layer?.masksToBounds = true

        serviceTableViewController.setup()

        popupController.willOpenPopup = { [weak self] _ in
            self?.serviceTableViewController.resizeViews()
            self?.serviceTableViewController.reloadData()
        }

        self.timer = Timer.scheduledTimer(timeInterval: 60,
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
        }
    }
}

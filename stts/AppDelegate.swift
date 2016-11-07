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
    var services: [Service]
    var servicesBeingUpdated = [Service]()
    var timer: Timer?

    let popupController: MBPopupController
    let serviceTableViewController: ServiceTableViewController

    override init() {
        self.services = Service.all().sorted()
        self.serviceTableViewController = ServiceTableViewController(services: services)
        self.popupController = MBPopupController(contentView: serviceTableViewController.contentView)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        popupController.statusItem.button?.title = "stts"
        popupController.statusItem.button?.font = NSFont(name: "SF Mono Regular", size: 10)
        popupController.statusItem.length = 30

        popupController.contentView.wantsLayer = true
        popupController.contentView.layer?.masksToBounds = true

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
        let callback: ((Service) -> ()) = { [weak self] service in self?.updatedStatus(for: service) }

        services.forEach {
            servicesBeingUpdated.append($0)
            $0.updateStatus(callback: callback)
        }
    }

    func updatedStatus(for service: Service) {
        if let index = servicesBeingUpdated.index(of: service) {
            servicesBeingUpdated.remove(at: index)
        }

        DispatchQueue.main.async { [weak self] in
            self?.serviceTableViewController.reloadData()
        }

        updateStatusBarItemStatus()
    }

    func updateStatusBarItemStatus() {
        popupController.statusItem.title = services.filter { service in
            service.status != .good && service.status != .undetermined
        }.count > 0 ? "s__s" : "stts"
    }
}

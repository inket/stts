//
//  SwitchableTableViewController.swift
//  stts
//

import Cocoa

protocol SwitchableTableViewController: AnyObject {
    var hidden: Bool { get set }

    func show()
    func hide()
    func willShow()
    func willHide()
}

extension SwitchableTableViewController {
    func show() {
        self.hidden = false
        self.willShow()
    }

    func hide() {
        self.hidden = true
        self.willHide()
    }
}

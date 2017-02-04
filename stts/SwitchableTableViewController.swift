//
//  SwitchableTableViewController.swift
//  stts
//

import Cocoa

protocol SwitchableTableViewController {
    var hidden: Bool { get set }

    mutating func show()
    mutating func hide()
    func willShow()
    func willHide()
}

extension SwitchableTableViewController {
    mutating func show() {
        self.hidden = false
        self.willShow()
    }

    mutating func hide() {
        self.hidden = true
        self.willHide()
    }
}

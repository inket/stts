//
//  CustomScrollView.swift
//  stts
//

import Cocoa

class CustomScrollView: NSScrollView {
    var topConstraint: NSLayoutConstraint?

    override var isOpaque: Bool {
        return false
    }
}

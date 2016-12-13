//
//  CustomScrollView.swift
//  stts
//

import Cocoa
import SnapKit

class CustomScrollView: NSScrollView {
    var topConstraint: Constraint?

    override var isOpaque: Bool {
        return false
    }
}

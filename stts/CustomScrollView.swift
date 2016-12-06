//
//  CustomScrollView.swift
//  stts
//
//  Created by inket on 3/11/16.
//  Copyright © 2016 inket. All rights reserved.
//

import Cocoa
import SnapKit

class CustomScrollView: NSScrollView {
    var topConstraint: Constraint?

    override var isOpaque: Bool {
        return false
    }
}

//
//  SettingsView.swift
//  stts
//
//  Created by inket on 05/12/2016.
//  Copyright © 2016 inket. All rights reserved.
//

import Cocoa
import SnapKit

class SettingsView: NSView {
    let settingsHeader = SectionHeaderView(name: "Preferences")
    let startAtLoginCheckbox = NSButton()
    let notifyCheckbox = NSButton()

    let servicesHeader = SectionHeaderView(name: "Services")

    init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(frame: .zero)
        setup()
    }

    func setup() {
        addSubview(settingsHeader)
        addSubview(startAtLoginCheckbox)
        addSubview(notifyCheckbox)
        addSubview(servicesHeader)

        let smallFont = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))

        startAtLoginCheckbox.setButtonType(.switch)
        startAtLoginCheckbox.title = "Start at Login"
        startAtLoginCheckbox.font = smallFont
        notifyCheckbox.setButtonType(.switch)
        notifyCheckbox.title = "Notify when a status changes"
        notifyCheckbox.font = smallFont

        settingsHeader.snp.makeConstraints { make in
            make.top.left.equalTo(6)
            make.right.equalTo(-6)
            make.height.equalTo(16)
        }

        startAtLoginCheckbox.snp.makeConstraints { make in
            make.top.equalTo(settingsHeader.snp.bottom).offset(6)
            make.left.equalTo(14)
            make.right.equalTo(-14)
            make.height.equalTo(18)
        }

        notifyCheckbox.snp.makeConstraints { make in
            make.top.equalTo(startAtLoginCheckbox.snp.bottom).offset(6)
            make.left.equalTo(14)
            make.right.equalTo(-14).priority(200)
            make.height.equalTo(18)
        }

        servicesHeader.snp.makeConstraints { make in
            make.top.equalTo(notifyCheckbox.snp.bottom).offset(10)
            make.left.equalTo(6)
            make.right.equalTo(-6)
            make.height.equalTo(16)
        }
    }
}

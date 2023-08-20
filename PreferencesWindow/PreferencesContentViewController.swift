//
//  PreferencesContentViewController.swift
//  PreferencesWindow
//

import Cocoa

class PreferencesContentViewController: NSViewController {
    var currentView: PreferencesView? {
        didSet {
            oldValue?.removeFromSuperview()

            if let currentView {
                currentView.willShow()

                currentView.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(currentView)

                NSLayoutConstraint.activate([
                    currentView.topAnchor.constraint(equalTo: view.topAnchor),
                    currentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    currentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    currentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

                    currentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
                    currentView.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
                ])
            }
        }
    }

    override func loadView() {
        view = NSView()
    }
}

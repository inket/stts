//
//  Appearance.swift
//  stts
//

import Cocoa

protocol AppearanceObserver: AnyObject {
    @MainActor func changeAppearance(to newAppearance: NSAppearance)
}

class Appearance {
    class Weak {
        fileprivate weak var object: AnyObject?

        init(_ object: AnyObject) {
            self.object = object
        }
    }

    private static var effectiveAppearanceObserver: Any? = {
        return NSApplication.shared.observe(
            \NSApplication.effectiveAppearance,
            options: [.new, .initial]
        ) { _, change in
            guard let newValue = change.newValue else { return }

            Appearance.fire(newAppearance: newValue)
        }
    }()

    private static var observers = [Weak]()

    private static func fire(newAppearance: NSAppearance) {
        // `NSApplication.observe`'s change handler isn't `@MainActor`-isolated in its declared
        // signature, but KVO on `effectiveAppearance` only ever fires on the main thread — so this
        // is a real guarantee the compiler just can't see, not an assumption.
        MainActor.assumeIsolated {
            observers = observers.filter {
                guard let object = $0.object else { return false }

                (object as? AppearanceObserver)?.changeAppearance(to: newAppearance)
                return true
            }
        }
    }

    static func addObserver(_ observer: AppearanceObserver) {
        observers = observers.filter { $0.object != nil }
        observers.append(Weak(observer))

        if effectiveAppearanceObserver == nil {
            fatalError("Did not setup appearance observer.")
        }
    }

    static func removeObserver(_ observer: AppearanceObserver) {
        observers = observers.filter { $0.object != nil && $0.object !== observer }
    }
}

extension NSAppearance {
    var isDarkMode: Bool {
        name == .darkAqua || name == .vibrantDark
    }
}

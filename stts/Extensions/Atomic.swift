//
//  Atomic.swift
//  stts
//

import Foundation
import os.lock

private final class UnfairLock {
    private var _lock: UnsafeMutablePointer<os_unfair_lock>

    init() {
        _lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        _lock.initialize(to: os_unfair_lock())
    }

    deinit {
        _lock.deallocate()
    }

    func locked<ReturnValue>(_ f: () throws -> ReturnValue) rethrows -> ReturnValue {
        os_unfair_lock_lock(_lock)
        defer { os_unfair_lock_unlock(_lock) }
        return try f()
    }
}

@propertyWrapper
public struct Atomic<Value> {
    private let lock = UnfairLock()
    private var value: Value

    public init(wrappedValue initialValue: Value) {
        value = initialValue
    }

    public var wrappedValue: Value {
        get {
            return lock.locked { value }
        }
        set(newValue) {
            lock.locked {
                value = newValue
            }
        }
    }
}

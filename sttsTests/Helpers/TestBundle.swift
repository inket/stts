//
//  TestBundle.swift
//  sttsTests
//

import Foundation

private class TestBundle {}

extension Bundle {
    static var test: Bundle {
        Bundle(for: TestBundle.self)
    }
}

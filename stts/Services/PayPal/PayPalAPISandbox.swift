//
//  PayPalAPISandbox.swift
//  stts
//

import Foundation

final class PayPalAPISandbox: PayPal {
    let name = "PayPal API (Sandbox)"
    let component = PayPalComponent.api(.sandbox)
}

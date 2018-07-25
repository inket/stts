//
//  PayPalAPISandbox.swift
//  stts
//

import Foundation

class PayPalAPISandbox: PayPal {
    let name = "PayPal API (Sandbox)"
    let component = PayPalComponent.api(.sandbox)
}

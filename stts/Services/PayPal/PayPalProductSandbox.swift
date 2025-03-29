//
//  PayPalProductSandbox.swift
//  stts
//

import Foundation

final class PayPalProductSandbox: PayPal {
    let name = "PayPal Product (Sandbox)"
    let component = PayPalComponent.product(.sandbox)
}

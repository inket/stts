//
//  PayPalAPIProduction.swift
//  stts
//

import Foundation

final class PayPalAPIProduction: PayPal {
    let name = "PayPal API"
    let component = PayPalComponent.api(.production)
}

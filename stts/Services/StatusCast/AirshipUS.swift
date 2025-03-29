//
//  AirshipUS.swift
//  stts
//

import Foundation

final class AirshipUS: StatusCastService {
    let name = "Airship (US)"
    let hasCurrentStatus = true
    let url = URL(string: "https://status.airship.com")!
}

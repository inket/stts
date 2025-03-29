//
//  StatusCast.swift
//  stts
//

import Foundation

final class StatusCast: StatusCastService {
    let hasCurrentStatus = false
    let url = URL(string: "https://status.statuscast.com")!
}

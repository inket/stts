//
//  Fastly.swift
//  stts
//

import Foundation

final class Fastly: StatusCastService {
    let hasCurrentStatus = false
    let url = URL(string: "https://www.fastlystatus.com")!
}

//
//  AuthorizeNet.swift
//  stts
//

import Foundation

final class AuthorizeNet: StatusPageService {
    let name = "Authorize.Net"
    let url = URL(string: "https://status.authorize.net")!
    let statusPageID = "06v575cbzlpr"
}

//
//  JAMF.swift
//  stts
//

import Foundation

final class JAMF: StatusPageService {
    let url = URL(string: "https://status.jamf.com")!
    let statusPageID = "5z7bmx2nb2yj"
}

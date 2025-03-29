//
//  Postmark.swift
//  stts
//

import Foundation

final class Postmark: SorryService {
    let url = URL(string: "https://status.postmarkapp.com")!
    let pageID = "12903"
}

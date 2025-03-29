//
//  HashiCorp.swift
//  stts
//

import Foundation

final class HashiCorp: StatusPageService {
    let url = URL(string: "https://status.hashicorp.com")!
    let statusPageID = "pdrzb3d64wsj"
}

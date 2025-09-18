//
//  HashiCorp.swift
//  stts
//

import Foundation

final class HashiCorp: IncidentIOService {
    let url = URL(string: "https://status.hashicorp.com")!
}

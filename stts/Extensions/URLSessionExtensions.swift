//
//  URLSessionExtensions.swift
//  stts
//
//  Created by inket on 13/06/2019.
//  Copyright © 2019 inket. All rights reserved.
//

import Foundation

private var _sharedWithoutCaching: URLSession?

extension URLSession {
    static var sharedWithoutCaching: URLSession {
        if let session = _sharedWithoutCaching {
            return session
        } else {
            let config = URLSessionConfiguration.default
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            config.urlCache = nil

            let session = URLSession(configuration: config)
            _sharedWithoutCaching = session
            return session
        }
    }
}

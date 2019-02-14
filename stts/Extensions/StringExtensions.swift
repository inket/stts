//
//  StringExtensions.swift
//  stts
//

import Foundation

extension String {
    var innerJSONString: String {
        let callbackPrefix = "jsonCallback("
        let callbackSuffix = ");"

        guard hasPrefix(callbackPrefix) && hasSuffix(callbackSuffix) else { return self }

        return String(self[
            index(startIndex, offsetBy: callbackPrefix.count) ..< index(endIndex, offsetBy: -callbackSuffix.count)
        ])
    }
}

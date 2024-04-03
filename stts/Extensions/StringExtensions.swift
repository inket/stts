//
//  StringExtensions.swift
//  stts
//

import Cocoa

extension String {
    var innerJSONString: String {
        let callbackPrefix = "jsonCallback("
        let callbackSuffix = ");"

        let trimmedString = trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedString.hasPrefix(callbackPrefix) && trimmedString.hasSuffix(callbackSuffix) else { return self }

        return String(trimmedString[
            trimmedString.index(trimmedString.startIndex, offsetBy: callbackPrefix.count) ..<
            trimmedString.index(trimmedString.endIndex, offsetBy: -callbackSuffix.count)
        ])
    }

    func height(forWidth width: CGFloat, font: NSFont) -> CGFloat {
        guard count > 0 else { return 0 }

        let attributedString = NSAttributedString(
            string: self,
            attributes: [.font: font]
        )

        let size = NSSize(width: width, height: .infinity)
        let textContainer = NSTextContainer(containerSize: size)
        let textStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()

        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.hyphenationFactor = 0
        layoutManager.typesetterBehavior = .latestBehavior

        // NSLayoutManager is lazy, so force it to calculate with this
        _ = layoutManager.glyphRange(for: textContainer)

        var result = layoutManager.usedRect(for: textContainer).size.height

        let extraLineSize = layoutManager.extraLineFragmentRect.size
        if extraLineSize.height > 0 {
            result -= extraLineSize.height
        }

        return result
    }

    var unescaped: String {
        var result = self

        // Convert escape sequences to the actual characters
        let entities = ["\0", "\t", "\n", "\r", "\"", "\'", "\\"]
        for entity in entities {
            let descriptionCharacters = entity.debugDescription.dropFirst().dropLast()
            let description = String(descriptionCharacters)
            result = result.replacingOccurrences(of: description, with: entity)
        }

        let invalidEscapedCharacters: [String: String] = ["\\\n": "\\n"]
        for (character, replacement) in invalidEscapedCharacters {
            result = result.replacingOccurrences(of: character, with: replacement)
        }

        // Convert unicode code points to characters: \u003e becomes >
        // swiftlint:disable:next force_try
        let regularExpression = try! NSRegularExpression(pattern: "\\\\u([A-Za-z0-9]{4})")
        var offset = 0
        regularExpression.enumerateMatches(
            in: result,
            range: NSRange(location: 0, length: (result as NSString).length),
            using: { textCheckingResult, _, _ in
                guard let textCheckingResult, textCheckingResult.numberOfRanges > 1 else { return }

                let actualRange = NSRange(
                    location: textCheckingResult.range.location + offset,
                    length: textCheckingResult.range.length
                )
                let codePointRange = NSRange(
                    location: textCheckingResult.range(at: 1).location + offset,
                    length: textCheckingResult.range(at: 1).length
                )

                let codePoint = (result as NSString).substring(with: codePointRange)

                guard
                    let codePointInt = UInt32(codePoint, radix: 16),
                    let scalar = Unicode.Scalar(codePointInt)
                else { return }
                let replacement = String(scalar)

                result = (result as NSString).replacingCharacters(
                    in: actualRange,
                    with: replacement
                )
                offset += (replacement.count - textCheckingResult.range.length)
            }
        )

        return result
    }
}

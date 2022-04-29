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
}

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Backfills Resources/Favicons/<providerIdentifier>.<alphanumericName>.png (flat, one directory)
// for every services.json entry, so the app bundles favicons instead of fetching them live
// (avoids a per-user, per-provider network hit against every status page). Filename matches
// ServiceDefinition.globalIdentifier ("<providerIdentifier>.<alphanumericName>") exactly, so the
// client needs no extra JSON field to find its bundled icon. Deliberately flat, not nested in a
// per-provider subdirectory: the provider prefix already guarantees uniqueness (verified zero
// cross-provider name collisions across the whole file), so nesting bought nothing but an extra
// Bundle.main lookup parameter.
final class FaviconDownloader {
    // Providers whose entries share one status page with no per-entry "url" in JSON — mirrors the
    // commonURL constants duplicated in stts/Services/Super/*.swift, plus Salesforce: its 12
    // products each get their own URL (see SalesforceServiceDefinition's formula in
    // stts/Services/Super/Salesforce.swift), but verified live that every /products/<X> page is a
    // byte-identical SPA shell serving one shared favicon.ico regardless of product — there's no
    // real per-product branding to lose by treating it the same as AWS/Adobe/Azure here.
    private let commonURLByProvider: [String: URL] = [
        "azure": URL(string: "https://azure.status.microsoft/en-us/status")!,
        "azuredevops": URL(string: "https://status.dev.azure.com")!,
        "firebase": URL(string: "https://status.firebase.google.com")!,
        "googlecloudplatform": URL(string: "https://status.cloud.google.com")!,
        "apple": URL(string: "https://www.apple.com/support/systemstatus/")!,
        "appledeveloper": URL(string: "https://developer.apple.com/system-status/")!,
        "awsregions": URL(string: "https://health.aws.amazon.com/health/status")!,
        "awsservices": URL(string: "https://health.aws.amazon.com/health/status")!,
        "adobe": URL(string: "https://status.adobe.com")!,
        "salesforce": URL(string: "https://status.salesforce.com")!
    ]

    // Providers whose entries are all regional deployments of one product: unlike the group above,
    // each has its own "url" in JSON, so they'd otherwise take the per-entry path below and write
    // one byte-identical file per region — 11 of them for Sendbird. Worse, those copies drift:
    // every Sendbird region is a separate Atlassian Statuspage account uploading its own favicon,
    // and Canada's and Tokyo's were still serving the pre-rebrand purple mark while the other nine
    // had the current one. Fetch once from the company's real site instead — same reasoning as
    // faviconSourceOverride below, that the company's own site is the canonical current branding
    // rather than whatever a given status page happens to have uploaded — and write it to
    // "<providerKey>.png", which ServiceDefinition.faviconURL already falls back to when no
    // per-entry file exists.
    private let singleBrandProviderURL: [String: URL] = [
        "sendbird": URL(string: "https://sendbird.com")!
    ]

    // Unlike the other 8 Salesforce products, these are separately-branded companies with their
    // own real public website distinct from status.salesforce.com's shared shell — verified live,
    // so their entries get that product's own favicon instead of the generic Salesforce one.
    // Spiff is deliberately excluded: spiff.com now redirects into a generic salesforce.com
    // marketing page (post-acquisition) with no distinct branding left to fetch, so it falls back
    // to the shared Salesforce favicon like the other 8.
    private let officialWebsiteByProduct: [String: URL] = [
        "Heroku": URL(string: "https://www.heroku.com")!,
        "Tableau": URL(string: "https://www.tableau.com")!,
        "Mulesoft": URL(string: "https://www.mulesoft.com")!
    ]

    // One-off overrides for individual entries whose own status-check URL (the "url" in JSON,
    // used to actually monitor the service) has no usable favicon, but the company's real website
    // does — keyed by the same "<providerKey>.<alphanumericName>" scheme as
    // ServiceDefinition.globalIdentifier. Only changes where the favicon is *fetched from*, never
    // the entry's monitored URL.
    //
    // The bulk of these (everything but MailChimp) were added after noticing a whole class of
    // wrong duplicates: several status-hosting platforms (Atlassian Statuspage, BetterStack,
    // status.io v1, incident.io) serve their own generic default favicon when a customer never
    // configured one, and that was being scraped as if it were the real per-service icon — verified
    // live, one at a time, that each of these has its own distinct, working favicon on its actual
    // company site instead.
    private let faviconSourceOverride: [String: URL] = [
        "statuscake.MailChimp": URL(string: "https://mailchimp.com")!,
        // status.beanstalkapp.com declares <link rel="shortcut icon"> pointing at
        // beanstalkapp.com/images/favicon.ico, which 404s — the real site moved its icon to a
        // content-hashed path, so scrape the site itself and let the finder pick that up.
        "independent.Beanstalk": URL(string: "https://beanstalkapp.com")!,
        // Atlassian Statuspage default icon was being scraped instead of the real site's:
        "statuspage.CloudAMQP": URL(string: "https://www.cloudamqp.com")!,
        "statuspage.CocoaPods": URL(string: "https://cocoapods.org")!,
        "statuspage.Coveralls": URL(string: "https://coveralls.io")!,
        "statuspage.Figma": URL(string: "https://www.figma.com")!,
        "statuspage.FreeAgent": URL(string: "https://www.freeagent.com")!,
        "statuspage.InternetComputer": URL(string: "https://internetcomputer.org")!,
        "statuspage.Loggly": URL(string: "https://www.loggly.com")!,
        "statuspage.Papertrail": URL(string: "https://www.papertrail.com")!,
        "statuspage.Python": URL(string: "https://www.python.org")!,
        "statuspage.Stream": URL(string: "https://getstream.io")!,
        "statuspage.Tyk": URL(string: "https://tyk.io")!,
        "statuspage.Wasabi": URL(string: "https://wasabi.com")!,
        "statuspage.Wodby": URL(string: "https://wodby.com")!,
        "statuspage.Cloud66": URL(string: "https://www.cloud66.com")!,
        // BetterStack's favicon isn't a logo at all — it's a live status badge, literally named
        // "operational-*.png"/"downtime-*.png" and changing as the monitored service's status
        // changes, so every single BetterStack/BetterUptime-hosted entry needs an override, not
        // just the ones that happened to look like duplicates:
        "betterstack.BetterStack": URL(string: "https://www.betterstack.com")!,
        "betterstack.Keygen": URL(string: "https://keygen.sh")!,
        "betterstack.RunwayAppStoreConnect": URL(string: "https://www.runway.team")!,
        "betterstack.Unraid": URL(string: "https://unraid.net")!,
        "betteruptime.Runway": URL(string: "https://www.runway.team")!,
        "betteruptime.PlausibleAnalytics": URL(string: "https://plausible.io")!,
        // status.io v1 default icon:
        "statusiov1.ClickUp": URL(string: "https://clickup.com")!,
        "statusiov1.CoreWeave": URL(string: "https://www.coreweave.com")!,
        "statusiov1.Roblox": URL(string: "https://www.roblox.com")!,
        // incident.io default icon:
        "incidentio.Brevo": URL(string: "https://www.brevo.com")!,
        "incidentio.CodeClimate": URL(string: "https://codeclimate.com")!,
        // status.aiven.io's icon is a white crab on transparency — invisible on the popup's white
        // favicon chip. aiven.io's own icon is the coloured mark:
        "incidentio.Aiven": URL(string: "https://aiven.io")!,
        // statuscast.StatusCast's own status page (unlike its siblings here) was serving Campaign
        // Monitor's logo, not its own — verified by comparing against statuscast.com's real
        // favicon (a purple square with a white star) side by side. airship.eu doesn't resolve as
        // a real site at all and status.airship.eu's favicon is a stale/outdated Airship wordmark
        // that doesn't match their current logo (status.airship.com's already-correct favicon
        // does) — pointing both regions at the one real airship.com keeps them consistent.
        "statuscast.StatusCast": URL(string: "https://www.statuscast.com")!,
        "statuscast.AirshipEU": URL(string: "https://www.airship.com")!
    ]

    private let maxDimension: CGFloat = 128
    private let maxConcurrentFetches = 8
    // normalizeToPNG never upscales, so an output smaller than this reflects a genuinely low-res
    // source (some status pages only have a tiny favicon) — worth checking the company's actual
    // main site for a better one when that happens.
    private let minAcceptableDimension = 32

    private let servicesPath: String
    private let faviconsDir: String

    init(servicesPath: String, faviconsDir: String) {
        self.servicesPath = servicesPath
        self.faviconsDir = faviconsDir
    }

    private struct Job {
        let providerKey: String
        let filename: String // "<providerKey>.<alphanumericName>.png" or "<providerKey>.png" (shared)
        let pageURL: URL
    }

    // Every entry under a commonURLByProvider provider shares the exact same page, so it would
    // otherwise get a byte-identical copy of the same icon at its own per-entry path (this bit us
    // for real: AWS's 306 entries and Adobe's 80 were each writing 300+ duplicate files). Instead,
    // those providers get exactly one file at "<providerKey>.png"; ServiceDefinition.faviconURL in
    // the app falls back to it when no per-entry file exists.

    func run(forceRefresh: Bool) async {
        guard
            let text = try? String(contentsOfFile: servicesPath, encoding: .utf8),
            let root = try? JSONParser.parse(text),
            let pairs = root.objectPairs
        else {
            print("error: could not read \(servicesPath)")
            return
        }

        var jobs: [Job] = []
        var expected = Set<String>()

        for (providerKey, value) in pairs where providerKey != "_removed" {
            guard let entries = value.arrayItems else { continue }
            let (providerJobs, providerExpected) = buildJobs(
                for: entries, providerKey: providerKey, forceRefresh: forceRefresh
            )
            jobs.append(contentsOf: providerJobs)
            expected.formUnion(providerExpected)
        }

        var providerByPageURL: [URL: String] = [:]
        for job in jobs { providerByPageURL[job.pageURL] = job.providerKey }

        let dataByPageURL = await fetchAndNormalize(providerByPageURL: providerByPageURL)

        try? FileManager.default.createDirectory(atPath: faviconsDir, withIntermediateDirectories: true)

        var written = 0
        var failed = 0
        for job in jobs {
            guard let data = dataByPageURL[job.pageURL] ?? nil else {
                failed += 1
                continue
            }

            let targetPath = "\(faviconsDir)/\(job.filename)"
            do {
                try data.write(to: URL(fileURLWithPath: targetPath))
                written += 1
            } catch {
                print("warning: could not write \(targetPath): \(error.localizedDescription)")
                failed += 1
            }
        }

        let deleted = cleanUpOrphans(expected: expected)

        print("Favicons: \(written) written, \(failed) failed/skipped, \(deleted) stale file(s) removed.")
    }

    private func buildJobs(for entries: [JSONValue], providerKey: String, forceRefresh: Bool) -> ([Job], Set<String>) {
        var jobs: [Job] = []
        var expected = Set<String>()
        var usesSharedFavicon = false

        // Short-circuits the per-entry loop entirely: one icon for the whole provider, however
        // many regions it lists. Safe to skip the product branch below too — a single-brand
        // provider has no separately-branded products to lose.
        if let sharedURL = singleBrandProviderURL[providerKey] {
            let filename = "\(providerKey).png"
            appendJobIfNeeded(
                &jobs, providerKey: providerKey, filename: filename,
                pageURL: sharedURL, forceRefresh: forceRefresh
            )
            expected.insert(filename)
            return (jobs, expected)
        }

        for entry in entries {
            guard
                let entryPairs = entry.objectPairs,
                let name = entryPairs.first(where: { $0.0 == "name" })?.1.stringValue
            else { continue }

            let ownURL = entryPairs.first(where: { $0.0 == "url" })?.1.stringValue.flatMap(URL.init(string:))
            let product = entryPairs.first(where: { $0.0 == "product" })?.1.stringValue

            if let ownURL {
                let filename = "\(providerKey).\(alphanumericName(name)).png"
                let fetchURL = faviconSourceOverride["\(providerKey).\(alphanumericName(name))"] ?? ownURL
                // Every sub-entry of a product (category row + each region) maps to the same
                // shared filename below, so only queue a fetch the first time we see it.
                if expected.insert(filename).inserted {
                    appendJobIfNeeded(
                        &jobs, providerKey: providerKey, filename: filename,
                        pageURL: fetchURL, forceRefresh: forceRefresh
                    )
                }
            } else if let product, let productURL = officialWebsiteByProduct[product] {
                let filename = "\(providerKey).\(alphanumericName(product)).png"
                if expected.insert(filename).inserted {
                    appendJobIfNeeded(
                        &jobs, providerKey: providerKey, filename: filename,
                        pageURL: productURL, forceRefresh: forceRefresh
                    )
                }
            } else if commonURLByProvider[providerKey] != nil {
                usesSharedFavicon = true
            }
        }

        if usesSharedFavicon, let sharedURL = commonURLByProvider[providerKey] {
            let filename = "\(providerKey).png"
            appendJobIfNeeded(
                &jobs, providerKey: providerKey, filename: filename,
                pageURL: sharedURL, forceRefresh: forceRefresh
            )
            expected.insert(filename)
        }

        return (jobs, expected)
    }

    private func appendJobIfNeeded(
        _ jobs: inout [Job], providerKey: String, filename: String, pageURL: URL, forceRefresh: Bool
    ) {
        let targetPath = "\(faviconsDir)/\(filename)"
        guard forceRefresh || !FileManager.default.fileExists(atPath: targetPath) else { return }
        jobs.append(Job(providerKey: providerKey, filename: filename, pageURL: pageURL))
    }

    // One fetch+normalize per unique page URL, however many entries share it (e.g. GCP's 174
    // entries all point at the same dashboard) — bounded concurrency so we don't hammer many
    // hosts at once.
    private func fetchAndNormalize(providerByPageURL: [URL: String]) async -> [URL: Data?] {
        var results: [URL: Data?] = [:]
        var iterator = providerByPageURL.makeIterator()

        await withTaskGroup(of: (URL, Data?).self) { group in
            func addNextTask() {
                guard let (pageURL, provider) = iterator.next() else { return }
                group.addTask {
                    // A handful of pages have failed to fetch under this tool's concurrent load
                    // while succeeding when hit standalone, so retry once before giving up —
                    // cheap insurance against transient network hiccups.
                    var found = await FaviconFinder.find(for: pageURL, provider: provider)
                    if found == nil {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        found = await FaviconFinder.find(for: pageURL, provider: provider)
                    }
                    guard let found else { return (pageURL, nil) }
                    guard let normalized = Self.normalizeToPNG(found.data, maxDimension: self.maxDimension) else {
                        return (pageURL, nil)
                    }

                    let better = await self.betterFaviconFromMainSite(
                        replacing: normalized, statusPageURL: pageURL, provider: provider
                    )
                    return (pageURL, better ?? normalized)
                }
            }

            for _ in 0..<maxConcurrentFetches { addNextTask() }
            while let (pageURL, data) = await group.next() {
                results[pageURL] = data
                addNextTask()
            }
        }

        return results
    }

    // Only derives a main-site candidate from a recognized status-subdomain naming convention on
    // the status page's own (already-verified-real) host — never guesses from the company name —
    // so this can never wander off to an unrelated site. Accepts the alternative only if it's both
    // fetchable and genuinely larger than what we already have.
    private func betterFaviconFromMainSite(
        replacing normalized: Data, statusPageURL: URL, provider: String
    ) async -> Data? {
        guard
            let originalDimensions = Self.pixelDimensions(of: normalized),
            min(originalDimensions.width, originalDimensions.height) < minAcceptableDimension,
            let mainSiteURL = Self.mainSiteCandidate(for: statusPageURL),
            let found = await FaviconFinder.find(for: mainSiteURL, provider: provider),
            let candidate = Self.normalizeToPNG(found.data, maxDimension: maxDimension),
            let candidateDimensions = Self.pixelDimensions(of: candidate)
        else { return nil }
        let originalMin = min(originalDimensions.width, originalDimensions.height)
        let candidateMin = min(candidateDimensions.width, candidateDimensions.height)
        guard candidateMin > originalMin else { return nil }

        return candidate
    }

    // e.g. "status.mailchimp.com" -> "mailchimp.com", "wpenginestatus.com" -> "wpengine.com",
    // "cloud-status.elastic.co" -> "elastic.co". Returns nil when the host doesn't match one of
    // these conventions rather than guessing.
    private static func mainSiteCandidate(for pageURL: URL) -> URL? {
        guard let host = pageURL.host else { return nil }
        var labels = host.split(separator: ".").map(String.init)
        guard let first = labels.first else { return nil }

        let statusSubdomains: Set<String> = ["status", "trust", "cloud-status"]
        if statusSubdomains.contains(first.lowercased()), labels.count > 2 {
            labels.removeFirst()
        } else if first.lowercased().hasSuffix("status"), first.count > "status".count {
            labels[0] = String(first.dropLast("status".count))
        } else {
            return nil
        }

        guard labels.count >= 2, !labels[0].isEmpty else { return nil }
        return URL(string: "https://\(labels.joined(separator: "."))")
    }

    private static func pixelDimensions(of data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return (width, height)
    }

    private func cleanUpOrphans(expected: Set<String>) -> Int {
        var deleted = 0
        let fileManager = FileManager.default

        guard let files = try? fileManager.contentsOfDirectory(atPath: faviconsDir) else { return 0 }

        for file in files where !expected.contains(file) {
            try? fileManager.removeItem(atPath: "\(faviconsDir)/\(file)")
            deleted += 1
        }

        return deleted
    }

    private func alphanumericName(_ name: String) -> String {
        String(name.unicodeScalars.filter(CharacterSet.alphanumerics.contains))
    }

    // Decodes whatever format was fetched (png/jpg/gif/ico — including picking the largest
    // representation out of a multi-resolution .ico) via ImageIO, downscaling only if larger than
    // maxDimension, and re-encodes as PNG. Falls back to rasterizing via AppKit's NSImage (which
    // has its own SVG renderer, unlike ImageIO) when ImageIO can't decode the data at all — chiefly
    // SVG favicons. Returns nil only if both paths fail.
    //
    // NSImage was chosen over shelling out to `qlmanage -t` (tried first): qlmanage's SVG
    // thumbnailer renders at the SVG's declared intrinsic pixel size regardless of the size
    // requested and pads the rest of the canvas with *opaque* white instead of scaling to fill it
    // or preserving transparency — confirmed by inspecting raw pixels of its output directly.
    // NSImage-based drawing does both correctly (verified the same way) with no extra dependency.
    private static func normalizeToPNG(_ data: Data, maxDimension: CGFloat) -> Data? {
        let normalized: Data?
        if let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 {
            normalized = normalizeDecodedImage(source: source, maxDimension: maxDimension)
        } else if let rasterized = rasterizeSVG(data, maxDimension: maxDimension),
                  let source = CGImageSourceCreateWithData(rasterized as CFData, nil) {
            normalized = normalizeDecodedImage(source: source, maxDimension: maxDimension)
        } else {
            normalized = nil
        }
        return normalized.map(stripNonEssentialPNGChunks)
    }

    // ImageIO/AppKit embed a freshly-generated ICC color profile (and other ancillary metadata) on
    // every encode that isn't byte-for-byte stable across separate runs, even when the actual pixel
    // content is 100% identical — confirmed by decoding two independently-fetched-and-encoded
    // copies of the same favicon and finding zero pixel differences, while only the `iCCP` chunk's
    // raw bytes differed between the two PNG files. That's a spurious diff every time this tool
    // regenerates an unchanged favicon. Strip everything but what's actually needed to decode the
    // image, so re-running this tool is byte-for-byte reproducible for unchanged source content
    // (and each file ends up a few hundred bytes smaller too).
    private static func stripNonEssentialPNGChunks(_ data: Data) -> Data {
        let bytes = [UInt8](data)
        guard bytes.count >= 8 else { return data }
        let essentialTypes: Set<String> = ["IHDR", "PLTE", "tRNS", "IDAT", "IEND"]

        var result = Data(bytes[0..<8])
        var offset = 8
        while offset + 8 <= bytes.count {
            let length = Int(bytes[offset]) << 24 | Int(bytes[offset + 1]) << 16
                | Int(bytes[offset + 2]) << 8 | Int(bytes[offset + 3])
            let chunkEnd = offset + 8 + length + 4
            guard chunkEnd <= bytes.count else { break }

            let type = String(bytes: bytes[(offset + 4)..<(offset + 8)], encoding: .utf8) ?? ""
            if essentialTypes.contains(type) {
                result.append(contentsOf: bytes[offset..<chunkEnd])
            }
            offset = chunkEnd
        }
        return result
    }

    private static func rasterizeSVG(_ data: Data, maxDimension: CGFloat) -> Data? {
        guard let image = NSImage(data: data) else { return nil }

        let size = NSSize(width: maxDimension, height: maxDimension)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        bitmap.size = size

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        NSGraphicsContext.current = context
        context.cgContext.clear(CGRect(origin: .zero, size: size))
        image.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1)

        return bitmap.representation(using: .png, properties: [:])
    }

    private static func normalizeDecodedImage(source: CGImageSource, maxDimension: CGFloat) -> Data? {
        var bestImage: CGImage?
        var bestArea = 0
        for index in 0..<CGImageSourceGetCount(source) {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            let area = image.width * image.height
            if area > bestArea {
                bestArea = area
                bestImage = image
            }
        }
        guard var image = bestImage else { return nil }

        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        if max(width, height) > maxDimension {
            let scale = maxDimension / max(width, height)
            let newWidth = max(1, Int((width * scale).rounded()))
            let newHeight = max(1, Int((height * scale).rounded()))
            // Always draw into an RGB context regardless of the source's color space — some
            // favicons are indexed/palette PNGs (colortype 3), and CGContext can't use an indexed
            // space as a drawing destination (silently fails to init). CGContext.draw() converts
            // from the source's actual color space automatically.
            guard
                let context = CGContext(
                    data: nil, width: newWidth, height: newHeight, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ),
                let resized = { () -> CGImage? in
                    context.interpolationQuality = .high
                    context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
                    return context.makeImage()
                }()
            else { return nil }
            image = resized
        }

        let outputData = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(outputData, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return outputData as Data
    }
}

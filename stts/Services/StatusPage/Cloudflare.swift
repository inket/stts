//
//  Cloudflare.swift
//  stts
//

import Foundation

final class Cloudflare: StatusPageService {
    let url = URL(string: "https://www.cloudflarestatus.com")!
    let statusPageID = "yh6f0r4529hb"

    override func updateStatus(from summary: BaseStatusPageService.Summary) {
        // Inline JS from https://www.cloudflarestatus.com
//        $('.component-inner-container').each(function() {
//              var el = $(this);
//              var stat = el.find(".component-status");
//              var mappings = {
//                "Partial Outage": "Re-routed",
//                "Major Outage": "Offline",
//                "Under Maintenance": "Partially Re-routed"
//              };
//              var paired;
//              if (paired = mappings[stat.text().trim()]) {
//                if (paired == 'Partially Re-routed') {
//                  groupName = el.parents('.component-container').find('span.name span').text()
//                  // skip non-PoP components when rewriting Under-Maintenance
//                  if (groupName.trim() == 'Cloudflare Sites and Services') return;
//                }
//                stat.text(paired);
//              }
//
//            });
//
//            var degradedStatus = false;
//            $('div.components-section span.component-status').each(function() {
//              var statusText = $(this).text().trim();
//              if(this.classList[1] == "tool" && statusText == 'Re-routed') $(this).hide();
//              if (!['Operational','Re-routed','Partially Re-routed'].includes(statusText)) {
//                degradedStatus = true;
//              }
//            });
//            if (!degradedStatus) {
//              minorStatusBar = $('div.page-status.status-minor');
//              minorStatusBarText = $('div.page-status.status-minor span.status');
//              if (minorStatusBar) {
//                minorStatusBar.removeClass('status-minor');
//                minorStatusBar.addClass('status-none');
//              }
//              if (minorStatusBarText) {
//                minorStatusBarText.text('All Systems Operational');
//              }
//            }
        let affectedComponents = summary.sortedComponents.filter {
            $0.status != .operational &&
            // "partial_outage" and "under_maintenance" are changed to "Re-routed" and "Partially re-routed" by inline
            // JS and do no affect the overall status on the page... except "Cloudflare Sites and Services" which
            // gets a pass when it's "under_maintenance"
            $0.status != .partialOutage &&
            ($0.name == "Cloudflare Sites and Services" || $0.status != .underMaintenance)
        }

        let degradedStatus = !affectedComponents.isEmpty

        let status: ServiceStatus
        let message: String
        if degradedStatus {
            status = summary.status.indicator.serviceStatus

            let detailedMessage: String

            // Set the message by combining the unresolved incident names
            let unresolvedIncidents = summary.incidents.filter { $0.isUnresolved }
            if !unresolvedIncidents.isEmpty {
                detailedMessage = unresolvedIncidents.map { "* \($0.name)" }.joined(separator: "\n")
            } else {
                // Or from the affected component names
                detailedMessage = affectedComponents
                    .map { "* \($0.name)" }
                    .joined(separator: "\n")
            }

            message = [summary.status.description, detailedMessage].joined(separator: "\n")
        } else {
            status = .good
            message = "All Systems Operational"
        }

        statusDescription = ServiceStatusDescription(status: status, message: message)
    }
}

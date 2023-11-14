//
//  IncidentIOService.swift
//  stts
//

import Foundation
import Kanna

typealias IncidentIOService = BaseIncidentIOService & RequiredServiceProperties & RequiredIncidentIOProperties

protocol RequiredIncidentIOProperties {}

class BaseIncidentIOService: BaseService {
    // 0 ongoingIncidents == operational
    //     let {ongoingIncidents: t, affectedComponents: n, structure: a, supportUrl: i, DetailOngoingIncidents: r, theme: s, noHeaderIcon: o=!1, useComponentsOverGroups: l=!1} = e,
    //         c = t.length,
    //         d = e3({
    //             ongoingIncidents: t,
    //             affectedComponents: n,
    //             structure: a
    //         }),
    //         p = Object.values(d).flat(),
    //         m = U().maxBy(p.map(e => {
    //             let {status: t} = e;
    //             return t
    //         }), e => D[e]) || (0 === c ? C.z2r.Operational : void 0);
    //

    // incidentCount == 0 ? "fully_operational" : "experiencing_issues"
    //     e5 = e => {
    //         let {incidentCount: t, status: n, noHeaderIcon: a=!1} = e,
    //             i = j("HeadsUp");
    //         return n === C.z2r.UnderMaintenance ? (0, u.jsx)("li", {
    //             className: "flex items-center text-slate-900 dark:text-slate-100",
    //             children: i("under_maintenance")
    //         }) : (0, u.jsxs)("li", {
    //             className: "flex items-center text-slate-900 dark:text-slate-100",
    //             children: [a ? null : n === C.z2r.Operational ? (0, u.jsx)(e1, {
    //                 className: "mr-2"
    //             }) : void 0 === n ? (0, u.jsx)(e0, {
    //                 className: "mr-2 text-slate-600 dark:text-slate-400"
    //             }) : null, i(0 === t ? "fully_operational" : "experiencing_issues")]
    //         })
    //     },

    //    HeadsUp: {
    //        under_maintenance: "We’re currently undergoing maintenance",
    //        fully_operational: "We’re fully operational",
    //        experiencing_issues: "We’re currently experiencing issues",

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? IncidentIOService else {
            fatalError("BaseIncidentIOService should not be used directly")
        }

        guard let host = realSelf.url.host else {
            _fail("Invalid URL")
            callback(self)
            return
        }

        var statusURLComponents = URLComponents()
        statusURLComponents.scheme = "https"
        statusURLComponents.host = host
        statusURLComponents.path = "/proxy/\(host)"

        guard let url = statusURLComponents.url else {
            _fail("Invalid URL")
            callback(self)
            return
        }

        loadData(with: url) { [weak self] data, _, error in
            guard let self else { return }
            defer { callback(self) }

            guard let data else { return self._fail(error) }

            guard let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return self._fail("Couldn't parse response")
            }

            guard
                let summary = dictionary["summary"] as? [String: Any],
                let ongoingIncidents = summary["ongoing_incidents"] as? [Any],
                let scheduledMaintenances = summary["scheduled_maintenances"] as? [Any]
            else {
                return self._fail("Unexpected response")
            }

            switch (ongoingIncidents.isEmpty, scheduledMaintenances.isEmpty) {
            case (true, true):
                self.statusDescription = ServiceStatusDescription(status: .good, message: "We’re fully operational")
            case (true, false):
                self.statusDescription = ServiceStatusDescription(
                    status: .maintenance,
                    message: "Scheduled maintenance" // We don't know if the maintenance is currently running
                )
            case (false, true), (false, false):
                self.statusDescription = ServiceStatusDescription(
                    status: .major,
                    message: "We’re currently experiencing issues"
                )
            }
        }
    }
}

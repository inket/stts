//
//  FirebaseAll.swift
//  stts
//

import Foundation

class Firebase: FirebaseService, ServiceCategory {
    let categoryName = "Firebase"
    let subServiceSuperclass: AnyObject.Type = BaseFirebaseService.self

    let name = "Firebase (All)"
}

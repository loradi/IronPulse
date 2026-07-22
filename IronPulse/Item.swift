//
//  Item.swift
//  IronPulse
//
//  Created by Diego on 2026-07-21.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

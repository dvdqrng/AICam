//
//  Item.swift
//  AICam
//
//  Created by David Quiring on 15.03.25.
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

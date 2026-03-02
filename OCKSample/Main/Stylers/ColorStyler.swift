//
//  ColorStyler.swift
//  OCKSample
//
//  Created by Corey Baker on 10/16/21.
//  Copyright © 2021 Network Reconnaissance Lab. All rights reserved.
//

import CareKitUI
import SwiftUI
import UIKit

// TODO: Replace placeholder values with your chosen BioMesh color palette.
struct ColorStyler: OCKColorStyler {
    #if os(iOS) || os(visionOS)
    // TODO: Change 1: primary label color
    var label: UIColor {
        FontColorKey.defaultValue
    }
    // TODO: Change 2: secondary label color
    var secondaryLabel: UIColor {
        UIColor.secondaryLabel
    }
    // TODO: Change 3: tertiary label / accent color
    var tertiaryLabel: UIColor {
        UIColor(Color.accentColor)
    }
    #endif
}

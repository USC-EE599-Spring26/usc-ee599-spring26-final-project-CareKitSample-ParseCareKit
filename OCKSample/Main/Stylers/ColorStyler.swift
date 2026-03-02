//
//  ColorStyler.swift
//  OCKSample
//
//  Created by Ray on 02/03/2026.
//  Copyright © 2026 Network Reconnaissance Lab. All rights reserved.
//


import CareKitUI
import SwiftUI
import UIKit

struct ColorStyler: OCKColorStyler {
    #if os(iOS) || os(visionOS)

    // BioMesh Primary Label Color (Main Text)
    var label: UIColor {
        UIColor(red: 0.08, green: 0.18, blue: 0.25, alpha: 1.0) 
        // Deep bio navy
    }

    // BioMesh Secondary Label Color
    var secondaryLabel: UIColor {
        UIColor(red: 0.25, green: 0.40, blue: 0.45, alpha: 1.0)
        // Muted blue-gray
    }

    // BioMesh Accent / Highlight Color
    var tertiaryLabel: UIColor {
        UIColor(red: 0.00, green: 0.60, blue: 0.55, alpha: 1.0)
        // Teal accent (BioMesh main accent)
    }

    #endif
}

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

    private var bioNavyLight: UIColor { UIColor(red: 0.08, green: 0.18, blue: 0.25, alpha: 1.0) }
    private var bioNavyDark: UIColor  { UIColor(red: 0.85, green: 0.92, blue: 0.95, alpha: 1.0) }

    private var bioSecondaryLight: UIColor { UIColor(red: 0.25, green: 0.40, blue: 0.45, alpha: 1.0) }
    private var bioSecondaryDark: UIColor  { UIColor(red: 0.70, green: 0.78, blue: 0.82, alpha: 1.0) }

    private var bioTeal: UIColor { UIColor(red: 0.00, green: 0.60, blue: 0.55, alpha: 1.0) }

    // Primary label color
    var label: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? self.bioNavyDark : self.bioNavyLight
        }
    }

    // Secondary label color
    var secondaryLabel: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? self.bioSecondaryDark : self.bioSecondaryLight
        }
    }

    // Accent / tertiary
    var tertiaryLabel: UIColor { bioTeal }

    #endif
}

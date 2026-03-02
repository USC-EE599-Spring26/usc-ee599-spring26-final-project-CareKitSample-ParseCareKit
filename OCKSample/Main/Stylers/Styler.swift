//
//  Styler.swift
//  OCKSample
//
//  Created by Corey Baker on 10/16/21.
//  Copyright © 2021 Network Reconnaissance Lab. All rights reserved.
//

import CareKitUI

// Styler wires together all four sub-stylers.
// ColorStyler    — color palette         (edit ColorStyler.swift)
// DimensionStyle — spacing / sizing      (edit OCKDimensionStyle.swift — already exists)
// BioMeshAnimationStyle  — motion        (edit OCKAnimationStyle.swift)
// BioMeshAppearanceStyle — shadow / look (edit OCKAppearanceStyle.swift)
struct Styler: OCKStyler {
    var color: OCKColorStyler {
        ColorStyler()
    }
    var dimension: OCKDimensionStyler {
        OCKDimensionStyle()
    }
    var animation: OCKAnimationStyler {
        BioMeshAnimationStyle()
    }
    var appearance: OCKAppearanceStyler {
        BioMeshAppearanceStyle()
    }
}

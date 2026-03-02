//
//  OCKAppearanceStyle.swift
//  OCKSample
//
//  Created by Faye on 2/28/26.
//  Copyright © 2026 Network Reconnaissance Lab. All rights reserved.
//
//  TODO (Teammate 3): Adjust the values below to finalize the BioMesh visual feel.
//  At least 3 changes are required for OCKAppearanceStyler per the assignment.
//

import CareKitUI
import UIKit

struct BioMeshAppearanceStyle: OCKAppearanceStyler {
    // TODO: Change 1: softer shadow opacity — cards feel lighter on screen
    var shadowOpacity: Float { 0.12 }

    // TODO: Change 2: slightly larger blur radius — smoother depth effect
    var shadowRadius: CGFloat { 10 }

    // TODO: Change 3: offset pushes shadow downward — standard material design feel
    var shadowOffset: CGSize { CGSize(width: 0, height: 4) }
}

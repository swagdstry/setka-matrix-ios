//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import SwiftUI

extension CGFloat {
    /// A layout dimension safe to use in frames and presentation detents.
    var sanitizedLayoutDimension: CGFloat? {
        isFinite && self > 0 ? self : nil
    }
}

extension View {
    /// Applies a fixed-height sheet detent when the total height is finite and positive; otherwise uses `fallback`.
    func presentationDetentHeight(contentHeight: CGFloat, additionalHeight: CGFloat = 0, fallback: PresentationDetent = .medium) -> some View {
        let total = contentHeight + additionalHeight
        if let total = total.sanitizedLayoutDimension {
            return presentationDetents([.height(total)])
        }
        return presentationDetents([fallback])
    }
    
    /// Reads the frame of the view and stores it in the `frame` binding.
    /// - Parameters:
    ///   - frame: a `CGRect` binding
    ///   - coordinateSpace: the coordinate space of the frame.
    func readFrame(_ frame: Binding<CGRect>, in coordinateSpace: CoordinateSpace = .local) -> some View {
        onGeometryChange(for: CGRect.self) { geometry in
            geometry.frame(in: coordinateSpace)
        } action: { newValue in
            guard newValue.origin.x.isFinite, newValue.origin.y.isFinite,
                  newValue.size.width.isFinite, newValue.size.height.isFinite else {
                return
            }
            frame.wrappedValue = newValue
        }
    }
    
    /// Reads the height of the view and stores it in the `height` binding.
    /// - Parameters:
    ///   - height: a `CGFloat` binding
    func readHeight(_ height: Binding<CGFloat>) -> some View {
        onGeometryChange(for: CGFloat.self) { geometry in
            geometry.size.height
        } action: { newValue in
            guard let newValue = newValue.sanitizedLayoutDimension else { return }
            height.wrappedValue = newValue
        }
    }
    
    /// Reads the width of the view and stores it in the `width` binding.
    /// - Parameters:
    ///   - width: a `CGFloat` binding
    func readWidth(_ width: Binding<CGFloat>) -> some View {
        onGeometryChange(for: CGFloat.self) { geometry in
            geometry.size.width
        } action: { newValue in
            guard let newValue = newValue.sanitizedLayoutDimension else { return }
            width.wrappedValue = newValue
        }
    }
}

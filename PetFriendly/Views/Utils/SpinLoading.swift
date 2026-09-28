//
//  SpinLoading.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 2025/10/15.
//


import SwiftUI

struct SpinLoading: View {
    let color: Color
    let lineWidth: CGFloat
    let size: CGFloat
    
    init(color: Color = .primary,
         lineWidth: CGFloat = 3,
         size: CGFloat = 20) {
        self.color = color
        self.lineWidth = lineWidth
        self.size = size
    }
    
    var body: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: color))
            .scaleEffect(size / 20.0)
            .frame(width: size, height: size)
    }
}

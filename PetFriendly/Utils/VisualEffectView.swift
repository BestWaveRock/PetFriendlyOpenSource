//
//  VisualEffectView.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 2025/10/10.
//


import SwiftUI

struct VisualEffectView: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemMaterial
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
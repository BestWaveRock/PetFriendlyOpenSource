//
//  PinCalloutView.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 2025/9/30.
//
import MapKit
import SwiftUI

struct PinCalloutView: View {
    let place: PetFriendlyPlace
    let onRate: () -> Void
    let onNav: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Button("contrib_reviews") { onRate() }
                .buttonStyle(CalloutButtonStyle(bg: .orange))
            Button("navigate_btn") { onNav() }
                .buttonStyle(CalloutButtonStyle(bg: .blue))
        }
        .padding(12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .cornerRadius(12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
        )
        .shadow(radius: 4)
    }
}

struct CalloutButtonStyle: ButtonStyle {
    let bg: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(bg.cornerRadius(8))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

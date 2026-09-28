//
//  PlaceAnnotationView.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 2025/8/15.
//

import SwiftUI

struct PlaceAnnotationView: View {
    let place: PetFriendlyPlace

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "pawprint.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundColor(.white)
                .padding(6)
                .background(Color.accentColor)
                .clipShape(Circle())

            Text(place.name)
                .font(.caption)
                .lineLimit(1)
        }
    }
}

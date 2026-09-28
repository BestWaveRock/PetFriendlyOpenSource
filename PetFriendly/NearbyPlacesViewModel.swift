//
//  NearbyPlacesViewModel.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 2025/8/15.
//

import SwiftUI
import MapKit

@MainActor
final class NearbyPlacesViewModel: ObservableObject {
    @Published var region = MKCoordinateRegion(
        center: .init(latitude: 39.9042, longitude: 116.4074),
        latitudinalMeters: 1000,
        longitudinalMeters: 1000
    )
    @Published var places: [PetFriendlyPlace] = []

}

//
//  AppState.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 2025/10/15.
//
import Foundation

class AppState: ObservableObject {
    static let shared = AppState()
    // system
    @Published var isRequestDown = false
    
    // place
    @Published var isLoadingPlaces = false
    @Published var showPlaceDetail = false
//    @Published var selectedPlace: PetFriendlyPlace?
    
    // map
    @Published var shouldZoomToFit = false
    

}

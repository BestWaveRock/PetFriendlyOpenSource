//
//  PlaceAnnotation.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 2025/9/30.
//
import MapKit
import SwiftUI

// 1. 自定义 Annotation，多带一个 placeID 方便回调
//final class PlaceAnnotation: NSObject, MKAnnotation {
//    let coordinate: CLLocationCoordinate2D
//    let place: PetFriendlyPlace
//    init(place: PetFriendlyPlace) {
//        self.coordinate = place.coordinate
//        self.place      = place
//        super.init()
//    }
//}

// 2. 自定义 AnnotationView，用 SwiftUI 视图当图标
//final class PlaceAnnotationView: MKAnnotationView {
//    static let reuseID = "placePin"
//    
//    override var annotation: MKAnnotation? {
//        didSet { updateIcon() }
//    }
//    
//    private func updateIcon() {
//        // 任意 SwiftUI Image → UIImage
//        let img = Image("pinIcon")          // Assets 里的图片
//                    .renderedAsUIImage(size: CGSize(width: 40, height: 40))
//        self.image = img
//        self.centerOffset = CGPoint(x: 0, y: -img.size.height/2) // 针尖对准坐标
//    }
//}

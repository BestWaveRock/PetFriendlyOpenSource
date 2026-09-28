//
//  LocationOnce.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 2025/9/24.
//


import CoreLocation

/// 取一次定位就停，回调在主线程
final class LocationOnce: NSObject, CLLocationManagerDelegate {
    private var mgr = CLLocationManager()
    private var callback: ((CLLocation) -> Void)?
    
    func fetch(_ cb: @escaping (CLLocation) -> Void) {
        print("🔍 LocationOnce.fetch entered")
        print("🔍 current auth status: \(CLLocationManager.authorizationStatus())")
        self.callback = cb
        mgr.delegate = self
        mgr.desiredAccuracy = kCLLocationAccuracyHundredMeters
        mgr.requestWhenInUseAuthorization()
        mgr.startUpdatingLocation()
        print("🔍 LocationOnce.fetch entered over")
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("🔍 didUpdateLocations fired")       // ← 3
        guard let loc = locations.first else { return }
        manager.stopUpdatingLocation()
        DispatchQueue.main.async { [weak self] in
            self?.callback?(loc)
            self?.callback = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        manager.stopUpdatingLocation()
    }
    
    deinit {
        print("🔥 LocationOnce deinit —— 对象已销毁！")
    }
}

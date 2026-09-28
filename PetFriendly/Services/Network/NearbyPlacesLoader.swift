//
//  NearbyPlacesLoader.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 2025/9/24.
//

import Foundation
import Combine

/// 负责拉取“附近场所”网络数据，并转成 Published 流
final class NearbyPlacesLoader: ObservableObject {
    
    /// 发完请求后把原始网络模型抛出去，由外部转本地模型
    @Published var places: [NearbyPlaceRow] = []
    @Published var error: String?
    
    /// 拉取接口（纬度、经度、可选关键字）
    func load(lat: Double, lon: Double, radius: Int, name: String?, placeLevel: Int, favoriteFlag: Bool) {
        print("🔍 loader.load called: lat=\(lat), lon=\(lon), radiu=\(radius), name=\(name ?? "nil"), placeLevel=\(placeLevel), favoriteFlag=\(favoriteFlag)")
        error = nil
        NetworkManager.shared.getNearbyPlaces(lat: lat,
                                              lon: lon,
                                              radius: radius,
                                              placeLevel: placeLevel,
                                              favoriteFlag: favoriteFlag,
                                              name: name) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let rows):
                    self?.places = rows
                    DispatchQueue.main.async {
                        AppState.shared.isLoadingPlaces = false
                        AppState.shared.shouldZoomToFit = true
                    }
                case .failure(let err):
                    self?.places = []
                    self?.error = err.localizedDescription
                }
            }
        }
    }
    
    func favoritePlace(placeId: String?, favoriteId: String?,
                       completion: @escaping (Result<BoolResp, Error>) -> Void) {
        print("💗 favoritePlace called: placeId \(placeId ?? "nil") favoriteId \(String(describing: favoriteId))")
        
        NetworkManager.shared.favoritePlaces(
                placeId: placeId,
                favoriteId: favoriteId)  { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let result):
                    completion(.success(result))
                case .failure(let err):
                    print("🔥 返回异常")   // ← 新增
                    completion(.failure(err))
                }
            }
        }
    }
}

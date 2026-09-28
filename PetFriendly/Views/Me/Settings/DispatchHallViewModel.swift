import SwiftUI
import Alamofire

class DispatchHallViewModel: ObservableObject {
    @Published var orders: [DispatchOrder] = []
    @Published var myOrders: [DispatchOrder] = []
    @Published var isLoading = false
    @Published var isLoadingMyOrders = false
    @Published var isLoadingMore = false
    @Published var isLoadingMoreMyOrders = false
    @Published var hasMore = true
    @Published var myHasMore = true
    @Published var errorMessage: String?
    @Published var selectedTab = 0  // 0=派单大厅, 1=我的接单
    
    private var pageNum = 1
    private var myPageNum = 1
    private let pageSize = 50
    
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    
    func loadOrders() {
        isLoading = true
        errorMessage = nil
        pageNum = 1
        hasMore = true
        
        // 获取当前位置
        if CLLocationManager.locationServicesEnabled() {
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.requestWhenInUseAuthorization()
            currentLocation = locationManager.location
        }
        
        Task {
            do {
                var params: [String: Any] = [
                    "pageNum": pageNum,
                    "pageSize": pageSize
                ]
                if let loc = currentLocation {
                    params["latitude"] = loc.coordinate.latitude
                    params["longitude"] = loc.coordinate.longitude
                    params["radius"] = 20000
                }
                
                let resp: DispatchHallResp = try await NetworkManager.shared.request(
                    "/petFriendly/client/dispatchHall/list",
                    method: .get,
                    parameters: params,
                    needToken: true,
                    showLoading: false
                )
                await MainActor.run {
                    orders = resp.rows ?? []
                    if let rows = resp.rows {
                        hasMore = rows.count == pageSize
                    }
                    pageNum += 1
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    func loadMoreOrders() {
        guard hasMore && !isLoading && !isLoadingMore else { return }
        isLoadingMore = true
        
        Task {
            do {
                var params: [String: Any] = [
                    "pageNum": pageNum,
                    "pageSize": pageSize
                ]
                if let loc = currentLocation {
                    params["latitude"] = loc.coordinate.latitude
                    params["longitude"] = loc.coordinate.longitude
                    params["radius"] = 20000
                }
                
                let resp: DispatchHallResp = try await NetworkManager.shared.request(
                    "/petFriendly/client/dispatchHall/list",
                    method: .get,
                    parameters: params,
                    needToken: true,
                    showLoading: false
                )
                await MainActor.run {
                    if let rows = resp.rows {
                        orders.append(contentsOf: rows)
                        hasMore = rows.count == pageSize
                    }
                    pageNum += 1
                    isLoadingMore = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoadingMore = false
                }
            }
        }
    }
    
    func loadMyOrders() {
        isLoadingMyOrders = true
        myPageNum = 1
        myHasMore = true
        Task {
            do {
                let params: [String: Any] = [
                    "pageNum": myPageNum,
                    "pageSize": pageSize
                ]
                let resp: DispatchHallResp = try await NetworkManager.shared.request(
                    "/petFriendly/client/dispatchHall/myOrders",
                    method: .get,
                    parameters: params,
                    needToken: true,
                    showLoading: false
                )
                await MainActor.run {
                    myOrders = resp.rows ?? []
                    if let rows = resp.rows {
                        myHasMore = rows.count == pageSize
                    }
                    myPageNum += 1
                    isLoadingMyOrders = false
                }
            } catch {
                await MainActor.run {
                    UIState.shared.showToast(error.localizedDescription)
                    isLoadingMyOrders = false
                }
            }
        }
    }
    
    func loadMoreMyOrders() {
        guard myHasMore && !isLoadingMyOrders && !isLoadingMoreMyOrders else { return }
        isLoadingMoreMyOrders = true
        Task {
            do {
                let params: [String: Any] = [
                    "pageNum": myPageNum,
                    "pageSize": pageSize
                ]
                let resp: DispatchHallResp = try await NetworkManager.shared.request(
                    "/petFriendly/client/dispatchHall/myOrders",
                    method: .get,
                    parameters: params,
                    needToken: true,
                    showLoading: false
                )
                await MainActor.run {
                    if let rows = resp.rows {
                        myOrders.append(contentsOf: rows)
                        myHasMore = rows.count == pageSize
                    }
                    myPageNum += 1
                    isLoadingMoreMyOrders = false
                }
            } catch {
                await MainActor.run {
                    UIState.shared.showToast(error.localizedDescription)
                    isLoadingMoreMyOrders = false
                }
            }
        }
    }
    
    /// 抢单：返回 nil 成功 / 非 nil 失败信息。B 方案：成功才关弹窗，失败保留可重试。
    func grabOrder(_ order: DispatchOrder) async -> String? {
        do {
            var params: [String: Any] = [
                "dispatchId": order.dispatchId ?? 0
            ]
            if let loc = currentLocation {
                params["providerLatitude"] = loc.coordinate.latitude
                params["providerLongitude"] = loc.coordinate.longitude
            }
            
            let resp: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                "/petFriendly/client/dispatchHall/grab",
                method: .post,
                parameters: params,
                encoding: JSONEncoding.default,
                needToken: true
            )
            if resp.code == 200 {
                await MainActor.run {
                    // 从列表中移除已抢订单
                    orders.removeAll { $0.dispatchId == order.dispatchId }
                    UIState.shared.showToast(NSLocalizedString("dispatch_grab_success", comment: ""))
                    // 刷新我的接单
                    loadMyOrders()
                }
                return nil
            }
            return resp.msg ?? NSLocalizedString("dispatch_grab_failed", comment: "")
        } catch {
            await MainActor.run {
                UIState.shared.showToast(error.localizedDescription)
            }
            return error.localizedDescription
        }
    }
    
    /// 取消接单：返回 nil 成功 / 非 nil 失败信息。B 方案：成功才关弹窗，失败保留可重试。
    func cancelOrder(_ order: DispatchOrder) async -> String? {
        do {
            let params: [String: Any] = [
                "dispatchId": order.dispatchId ?? 0,
                "reason": NSLocalizedString("dispatch_cancel_reason_provider", comment: "")
            ]
            let resp: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                "/petFriendly/client/dispatchHall/cancel",
                method: .post,
                parameters: params,
                encoding: JSONEncoding.default,
                needToken: true
            )
            if resp.code == 200 {
                await MainActor.run {
                    myOrders.removeAll { $0.dispatchId == order.dispatchId }
                    UIState.shared.showToast(NSLocalizedString("dispatch_cancel_success", comment: ""))
                }
                return nil
            }
            return resp.msg ?? NSLocalizedString("dispatch_cancel_failed", comment: "")
        } catch {
            await MainActor.run { UIState.shared.showToast(error.localizedDescription) }
            return error.localizedDescription
        }
    }
    
    /// 完结订单：返回 nil 成功 / 非 nil 失败信息。B 方案：成功才关弹窗，失败保留可重试。
    func completeOrder(_ order: DispatchOrder, certificate: String? = nil) async -> String? {
        do {
            var params: [String: Any] = [
                "consumerId": order.consumerId ?? 0
            ]
            if let cert = certificate, !cert.isEmpty {
                params["certificate"] = cert
            }
            let resp: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                "/petFriendly/client/service/order/complete",
                method: .post,
                parameters: params,
                encoding: JSONEncoding.default,
                needToken: true
            )
            if resp.code == 200 {
                await MainActor.run {
                    UIState.shared.showToast(NSLocalizedString("dispatch_complete_success", comment: ""))
                    loadMyOrders()
                }
                return nil
            }
            return resp.msg ?? NSLocalizedString("dispatch_complete_failed", comment: "")
        } catch {
            await MainActor.run { UIState.shared.showToast(error.localizedDescription) }
            return error.localizedDescription
        }
    }
    
    func uploadCertificate(_ image: UIImage, for order: DispatchOrder) async -> String? {
        do {
            let url: String = try await NetworkManager.shared.uploadImage(image, to: "/petFriendly/client/upload")
            // 上传成功后，如果需要提交到无犯罪记录接口可以使用下面的逻辑
            // 但这里我们用上传图片的URL，后续完成订单时一并提交
            return url
        } catch {
            await MainActor.run { UIState.shared.showToast(error.localizedDescription) }
            return nil
        }
    }
}

// MARK: - 派单大厅主视图

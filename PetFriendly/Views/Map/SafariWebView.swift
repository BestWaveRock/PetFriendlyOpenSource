import SwiftUI
import SafariServices
import MapKit
import WebKit

// MARK: - 内嵌浏览器（WKWebView），打开外部链接时可选注入客户端请求头与鉴权
struct InAppBrowserView: View {
    let url: URL
    var title: String? = nil
    /// 是否带上 App 已有请求头与 token（默认带；兼容无需鉴权的页面可传 false）
    var injectHeaders: Bool = true

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PFColors.background.ignoresSafeArea()
                InAppWebViewContainer(url: url, injectHeaders: injectHeaders)
            }
            .navigationTitle(title ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Text("common_close")
                            .fontWeight(.semibold)
                    }
                }
            }
            .onDisappear {
                // 离开浏览器后停止拦截，避免影响后续 App 请求
                InAppWebViewURLProtocol.targetHost = nil
                InAppWebViewURLProtocol.injectEnabled = true
            }
        }
    }
}

/// 注入客户端请求头（Authorization / X-APP-KEY / Content-Language / CliendId）的 WKWebView 容器
struct InAppWebViewContainer: UIViewRepresentable {
    let url: URL
    var injectHeaders: Bool = true

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        // 仅当需要注入时才启用拦截；不注入时直接放行，避免冲突
        InAppWebViewURLProtocol.injectEnabled = injectHeaders
        InAppWebViewURLProtocol.targetHost = injectHeaders ? url.host : nil
        InAppWebViewURLProtocol.register()

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        var request = URLRequest(url: url)
        if injectHeaders {
            InAppWebViewURLProtocol.applyAuthHeaders(&request)
        }
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            if InAppWebViewURLProtocol.injectEnabled {
                InAppWebViewURLProtocol.targetHost = webView.url?.host
            }
        }
    }
}

/// 拦截外链域名的 http(s) 请求并注入客户端请求头
final class InAppWebViewURLProtocol: URLProtocol {
    static var targetHost: String? = nil
    /// 是否启用请求头注入（可选：带 app 已有 header/token，或不带）
    static var injectEnabled = true
    private static var isRegistered = false
    private static var isHandling = false   // 防止递归

    static func register() {
        guard !isRegistered else { return }
        URLProtocol.registerClass(InAppWebViewURLProtocol.self)
        isRegistered = true
    }

    /// 构建客户端请求头
    static var authHeaders: [String: String] {
        var h: [String: String] = [
            "X-APP-KEY": Secrets.appKey,
            "CliendId": Secrets.clientId,
            "Content-Language": "zh_CN",
        ]
        if let token = NetworkManager.shared.token {
            h["Authorization"] = "Bearer \(token)"
        }
        return h
    }

    static func applyAuthHeaders(_ request: inout URLRequest) {
        for (k, v) in authHeaders {
            if request.value(forHTTPHeaderField: k) == nil {
                request.setValue(v, forHTTPHeaderField: k)
            }
        }
    }

    // 只拦截目标外链域名的请求，且是 http/https；处理中/内部请求不拦截，避免递归
    override class func canInit(with request: URLRequest) -> Bool {
        guard injectEnabled, !isHandling, let host = request.url?.host, let target = targetHost else { return false }
        return (request.url?.scheme == "http" || request.url?.scheme == "https")
            && host == target
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        var req = request
        applyAuthHeaders(&req)
        return req
    }

    override func startLoading() {
        var request = self.request
        InAppWebViewURLProtocol.applyAuthHeaders(&request)
        // 用不带自定义 protocol 的临时 session，避免递归进入本类
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = []
        let session = URLSession(configuration: config)
        session.dataTask(with: request) { [weak self] data, response, error in
            InAppWebViewURLProtocol.isHandling = false
            guard let self else { return }
            if let error = error {
                self.client?.urlProtocol(self, didFailWithError: error)
                return
            }
            if let response = response as? HTTPURLResponse {
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data = data {
                self.client?.urlProtocol(self, didLoad: data)
            }
            self.client?.urlProtocolDidFinishLoading(self)
        }.resume()
        InAppWebViewURLProtocol.isHandling = true
    }

    override func stopLoading() {
        InAppWebViewURLProtocol.isHandling = false
    }
}

struct SafariWebView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - MapViewRepresentable (保持原有逻辑)
struct MapViewRepresentable: UIViewRepresentable {
    @ObservedObject var vm: MapViewModel
    let nearbyFriends: [NearbyFriend]
    let messagePreviews: [String: NearbyMessagePreview]
    @EnvironmentObject var uiState: UIState
    @EnvironmentObject var accountStore: AccountStore
    @Binding var shouldZoomToFit: Bool
    let onMapReady: (MKMapView) -> Void
    let onSelectNearbyFriend: (NearbyFriend) -> Void
    var onLongPress: ((CLLocationCoordinate2D) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        map.addGestureRecognizer(longPress)
        
        onMapReady(map)
        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.parent = self
        if uiView.window != nil && uiView.showsUserLocation == false {
            uiView.showsUserLocation = true
        }
        
        // --- 0. 刷新当前定位大头针的头像 ---
        if let userLocationView = uiView.view(for: uiView.userLocation) as? UserLocationAnnotationView {
            let avatarStr: String?
            if NetworkManager.shared.token != nil {
                avatarStr = accountStore.petOwner?.petAvatar ?? accountStore.user?.avatar
            } else {
                avatarStr = nil
            }
            userLocationView.configure(with: avatarStr)
        }
        
        let coordinator = context.coordinator
        
        // --- 1. 半径圈同步 (Radius Circle) — 以屏幕中心准星为准
        let center: CLLocationCoordinate2D
        if uiView.bounds.width > 0 && uiView.bounds.height > 0 {
            let visualCenterPoint = CGPoint(
                x: uiView.bounds.midX,
                y: uiView.bounds.midY
            )
            center = uiView.convert(visualCenterPoint, toCoordinateFrom: uiView)
        } else if let vmCenter = vm.centerCoordinate {
            center = vmCenter
        } else {
            center = uiView.centerCoordinate
        }
        let radius = Double(vm.searchRadius)
        
        let currentCircles = uiView.overlays.compactMap { $0 as? MKCircle }
        let lastCenter = currentCircles.first?.coordinate
        let isCoordChanged = lastCenter == nil || 
                           abs(lastCenter!.latitude - center.latitude) > 0.0001 || 
                           abs(lastCenter!.longitude - center.longitude) > 0.0001
        
        let needsUpdate = currentCircles.isEmpty || 
                          currentCircles.first?.radius != radius ||
                          isCoordChanged
        
        if needsUpdate {
            uiView.removeOverlays(currentCircles)
            let circle = MKCircle(center: center, radius: radius)
            uiView.addOverlay(circle)
        }

        // --- 2. 标注同步 (Annotation Diffing) ---
        let currentAnnotations = uiView.annotations.compactMap { $0 as? PlaceAnnotation }
        let currentIds = Set(currentAnnotations.compactMap { $0.placeId })
        let newPlaces = vm.filteredPlaces
        let newIds = Set(newPlaces.compactMap { $0.placeId })
        
        if currentIds != newIds {
            let toRemove = currentAnnotations.filter { !newIds.contains($0.placeId ?? -1) }
            uiView.removeAnnotations(toRemove)
            
            let toAdd = newPlaces.filter { !currentIds.contains($0.placeId ?? -1) }
                                 .map { PlaceAnnotation(place: $0) }
            uiView.addAnnotations(toAdd)
        }


        // --- 3. 附近宠友标注同步：独立于场所筛选和刷新 ---
        let currentFriends = uiView.annotations.compactMap { $0 as? NearbyFriendAnnotation }
        let currentFriendIds = Set(currentFriends.map(\.userId))
        let newFriendIds = Set(nearbyFriends.map(\.userId))
        uiView.removeAnnotations(currentFriends.filter { !newFriendIds.contains($0.userId) })
        uiView.addAnnotations(nearbyFriends.filter { !currentFriendIds.contains($0.userId) }.map(NearbyFriendAnnotation.init))

        for annotation in currentFriends {
            guard let latest = nearbyFriends.first(where: { $0.userId == annotation.userId }) else { continue }
            let newCoordinate = CLLocationCoordinate2D(latitude: latest.latitude, longitude: latest.longitude)
            annotation.friend = latest
            if let marker = uiView.view(for: annotation) as? NearbyFriendAnnotationView {
                // configure 内部按 URL 和在途任务去重，地图拖动不会重置或重复下载头像。
                marker.configure(avatar: latest.userAvatar)
                marker.configure(message: messagePreviews[annotation.userId])
            }
            if abs(annotation.coordinate.latitude - newCoordinate.latitude) > 0.000001 ||
                abs(annotation.coordinate.longitude - newCoordinate.longitude) > 0.000001 {
                UIView.animate(withDuration: 0.8) { annotation.coordinate = newCoordinate }
            }
        }
        
        // 动态偏移 — 以屏幕中心准星为准
        let targetRegion = vm.targetRegion
        let targetCenter = targetRegion?.center
        let targetSpan = targetRegion?.span
        

        let movementKey = "\(targetCenter?.latitude ?? 0),\(targetCenter?.longitude ?? 0)_\(targetSpan?.latitudeDelta ?? 0)_\(vm.searchRadius)"
        
        let needsMovement = coordinator.lastMovementKey != movementKey
        
        if needsMovement {
            let prevVisualCenterPoint = CGPoint(
                x: uiView.bounds.midX,
                y: uiView.bounds.midY
            )
            let currentCoordinateAtCrosshair = uiView.convert(prevVisualCenterPoint, toCoordinateFrom: uiView)

            coordinator.lastMovementKey = movementKey
            coordinator.isProgrammaticRegionChange = true
            
            DispatchQueue.main.async {
                let targetCoord = vm.targetRegion?.center ?? currentCoordinateAtCrosshair
                let targetSpan = vm.targetRegion?.span ?? uiView.region.span
                
                let region = MKCoordinateRegion(center: targetCoord, span: targetSpan)
                uiView.setRegion(region, animated: true)
            }
        }
        
        // 高亮动画
        if let highlightId = vm.highlightedPlaceId,
           coordinator.lastHighlightedId != highlightId {
            coordinator.lastHighlightedId = highlightId
            
            DispatchQueue.main.async {
                for annotation in uiView.annotations {
                    if let markerView = uiView.view(for: annotation) as? MKMarkerAnnotationView {
                        markerView.displayPriority = .defaultLow
                        markerView.titleVisibility = .adaptive
                        markerView.layer.zPosition = 0
                    }
                }
                
                for annotation in uiView.annotations {
                    guard let placeAnno = annotation as? PlaceAnnotation,
                          placeAnno.placeId == highlightId,
                          let annoView = uiView.view(for: placeAnno) as? MKMarkerAnnotationView else { continue }
                    
                    annoView.displayPriority = .required
                    annoView.titleVisibility = .visible
                    annoView.layer.zPosition = 10000
                    coordinator.isProgrammaticSelect = true
                    uiView.selectAnnotation(placeAnno, animated: true)
                    coordinator.isProgrammaticSelect = false
                    
                    let shake = CAKeyframeAnimation(keyPath: "transform.rotation.z")
                    shake.values = [0, -0.25, 0.25, -0.20, 0.20, -0.12, 0.12, -0.06, 0]
                    shake.keyTimes = [0, 0.08, 0.2, 0.32, 0.44, 0.56, 0.7, 0.85, 1.0]
                    shake.duration = 0.7
                    shake.repeatCount = 2
                    annoView.layer.add(shake, forKey: "shakePin")
                    
                    let bounce = CAKeyframeAnimation(keyPath: "transform.scale")
                    bounce.values = [1.0, 1.5, 0.85, 1.25, 0.95, 1.1, 1.0]
                    bounce.keyTimes = [0, 0.15, 0.35, 0.5, 0.65, 0.8, 1.0]
                    bounce.duration = 0.7
                    annoView.layer.add(bounce, forKey: "bouncePin")
                    
                    let pulse = CALayer()
                    pulse.frame = annoView.bounds.insetBy(dx: -8, dy: -8)
                    pulse.cornerRadius = pulse.frame.width / 2
                    pulse.borderWidth = 3
                    pulse.borderColor = UIColor.systemBlue.cgColor
                    pulse.opacity = 0
                    annoView.layer.addSublayer(pulse)
                    
                    let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
                    scaleAnim.fromValue = 0.8
                    scaleAnim.toValue = 2.5
                    
                    let opacityAnim = CAKeyframeAnimation(keyPath: "opacity")
                    opacityAnim.values = [0.9, 0.6, 0]
                    opacityAnim.keyTimes = [0, 0.5, 1.0]
                    
                    let group = CAAnimationGroup()
                    group.animations = [scaleAnim, opacityAnim]
                    group.duration = 0.5
                    group.repeatCount = 4
                    group.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    pulse.add(group, forKey: "pulseGlow")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        pulse.removeFromSuperlayer()
                    }
                    
                    break
                }
            }
        } else if vm.highlightedPlaceId == nil {
            coordinator.lastHighlightedId = nil
            DispatchQueue.main.async {
                for annotation in uiView.annotations {
                    if let markerView = uiView.view(for: annotation) as? MKMarkerAnnotationView {
                        markerView.displayPriority = .required
                        markerView.titleVisibility = .adaptive
                        markerView.layer.zPosition = 0
                    }
                }
            }
        }
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        
        var lastMovementKey: String?
        var lastHighlightedId: Int64?
        var isProgrammaticSelect = false
        var isProgrammaticRegionChange = false
        
        init(_ parent: MapViewRepresentable) { self.parent = parent }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                let isDark = mapView.traitCollection.userInterfaceStyle == .dark
                renderer.fillColor = UIColor.systemBlue.withAlphaComponent(isDark ? 0.15 : 0.10)
                renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(isDark ? 0.6 : 0.4)
                renderer.lineWidth = 1.5
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            if gesture.state == .began {
                guard let mapView = gesture.view as? MKMapView else { return }
                let location = gesture.location(in: mapView)
                let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
                Haptics.play(.medium)
                parent.onLongPress?(coordinate)
            }
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                let identifier = UserLocationAnnotationView.reuseID
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? UserLocationAnnotationView
                if view == nil {
                    view = UserLocationAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                } else {
                    view?.annotation = annotation
                }
                
                let avatarStr: String?
                if NetworkManager.shared.token != nil {
                    avatarStr = AccountStore.shared.petOwner?.petAvatar ?? AccountStore.shared.user?.avatar
                } else {
                    avatarStr = nil
                }
                view?.configure(with: avatarStr)
                return view
            }

            if let friendAnnotation = annotation as? NearbyFriendAnnotation {
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: NearbyFriendAnnotationView.reuseID) as? NearbyFriendAnnotationView)
                    ?? NearbyFriendAnnotationView(annotation: friendAnnotation, reuseIdentifier: NearbyFriendAnnotationView.reuseID)
                view.annotation = friendAnnotation
                view.configure(avatar: friendAnnotation.friend.userAvatar)
                view.configure(message: parent.messagePreviews[friendAnnotation.userId])
                view.layer.zPosition = 30_000
                return view
            }
            
            guard let anno = annotation as? PlaceAnnotation else { return nil }
            
            let identifier = "PlaceMarker"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if view == nil {
                view = MKMarkerAnnotationView(annotation: anno, reuseIdentifier: identifier)
                view?.canShowCallout = false
            } else {
                view?.annotation = anno
                view?.canShowCallout = false
            }
            
            if let level = anno.placeLevel, level == 4 {
                view?.glyphImage = UIImage(systemName: "exclamationmark.triangle.fill")
                view?.markerTintColor = UIColor.systemRed
            } else if let place = parent.vm.filteredPlaces.first(where: { $0.placeId == anno.placeId }) {
                view?.glyphImage = UIImage(systemName: place.iconName)
                view?.markerTintColor = UIColor(place.iconColor)
            } else {
                view?.glyphImage = UIImage(systemName: anno.place.iconName)
                view?.markerTintColor = UIColor(anno.place.iconColor)
            }
            
            if let highlightId = parent.vm.highlightedPlaceId, anno.placeId == highlightId {
                view?.displayPriority = .required
                view?.titleVisibility = .visible
                view?.layer.zPosition = 20000
            } else {
                view?.displayPriority = .defaultLow
                view?.titleVisibility = .adaptive
                view?.layer.zPosition = 0
            }
            
            return view
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let friendAnnotation = view.annotation as? NearbyFriendAnnotation {
                mapView.deselectAnnotation(friendAnnotation, animated: false)
                parent.onSelectNearbyFriend(friendAnnotation.friend)
                return
            }
            guard let anno = view.annotation as? PlaceAnnotation else { return }
            if !isProgrammaticSelect {
                let targetPlace = anno.place
                DispatchQueue.main.async {
                    self.parent.vm.selectedPlace = targetPlace
                }
            }
            mapView.deselectAnnotation(anno, animated: false)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let visualCenterPoint = CGPoint(
                x: mapView.bounds.midX,
                y: mapView.bounds.midY
            )
            let visualCenterCoord = mapView.convert(visualCenterPoint, toCoordinateFrom: mapView)
            
            parent.vm.centerCoordinate = visualCenterCoord
            
            // 实时将圈中心点对齐当前屏幕中心，确保加载完全后精确更新 (iOS 27+)
            let radius = Double(parent.vm.searchRadius)
            let currentCircles = mapView.overlays.compactMap { $0 as? MKCircle }
            mapView.removeOverlays(currentCircles)
            let circle = MKCircle(center: visualCenterCoord, radius: radius)
            mapView.addOverlay(circle)
            
            if isProgrammaticRegionChange {
                isProgrammaticRegionChange = false
            } else {
                parent.vm.targetRegion = nil
                
                if UIState.shared.selectedTab == 0 && !UIState.shared.isSearching {
                    parent.vm.resetAndFetch(at: visualCenterCoord)
                    
                    if parent.vm.highlightedPlaceId != nil {
                        parent.vm.highlightedPlaceId = nil
                    }
                }
            }
        }
    }
}

// MARK: - 骨架屏组件

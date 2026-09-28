import SwiftUI
import MapKit

struct PlaceSkeletonView: View {
    @State private var opStatus = 0.3
    
    var body: some View {
        HStack(spacing: PFSpacing.md) {
            Circle()
                .fill(Color.gray.opacity(opStatus))
                .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(opStatus))
                    .frame(width: 140, height: 16)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(opStatus))
                    .frame(width: 220, height: 12)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(opStatus))
                    .frame(width: 80, height: 10)
            }
            Spacer()
        }
        .padding(PFSpacing.lg)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .pfCardShadow()
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                opStatus = 0.6
            }
        }
    }
}

class PlaceAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    @Int64String var placeId: Int64?
    let placeLevel: Int?
    let place: PetFriendlyPlace
    
    init(place: PetFriendlyPlace) {
        self.coordinate = place.coordinate
        self.title = place.name
        self.placeId = place.placeId
        self.placeLevel = place.placeLevel
        self.place = place
    }
}

final class NearbyFriendAnnotation: NSObject, MKAnnotation {
    let userId: String
    var friend: NearbyFriend
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String? { friend.userName ?? NSLocalizedString("nearby_pet_friend", comment: "") }

    init(friend: NearbyFriend) {
        self.userId = friend.userId
        self.friend = friend
        self.coordinate = CLLocationCoordinate2D(latitude: friend.latitude, longitude: friend.longitude)
        super.init()
    }

    func update(with friend: NearbyFriend) {
        self.friend = friend
        coordinate = CLLocationCoordinate2D(latitude: friend.latitude, longitude: friend.longitude)
    }
}

final class NearbyFriendAnnotationView: MKAnnotationView {
    static let reuseID = "NearbyFriendMarker"
    private let avatarView = UIImageView()
    private var representedURL: URL?
    private var loadedURL: URL?
    private var imageTask: URLSessionDataTask?
    private let messageBubble = UILabel()
    private var displayedMessageId: String?

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        // 与 MKUserLocation 自己的头像使用相同尺寸和中心锚点，确保同一坐标视觉重合。
        frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        centerOffset = .zero
        displayPriority = .required
        collisionMode = .circle
        canShowCallout = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.22
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 2)
        avatarView.frame = bounds
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 22
        avatarView.layer.borderWidth = 2.5
        avatarView.layer.borderColor = UIColor.systemGreen.cgColor
        addSubview(avatarView)

        messageBubble.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.96)
        messageBubble.textColor = .label
        messageBubble.font = .systemFont(ofSize: 12, weight: .medium)
        messageBubble.textAlignment = .center
        messageBubble.numberOfLines = 2
        messageBubble.layer.cornerRadius = 12
        messageBubble.layer.masksToBounds = true
        messageBubble.alpha = 0
        addSubview(messageBubble)
    }

    required init?(coder: NSCoder) { nil }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        imageTask = nil
        representedURL = nil
        loadedURL = nil
        displayedMessageId = nil
        messageBubble.alpha = 0
        avatarView.image = nil
    }

    func configure(avatar: String?) {
        let placeholder = UIImage(systemName: "person.crop.circle.fill")
        guard let url = NetworkManager.fullUrl(avatar) else {
            imageTask?.cancel()
            imageTask = nil
            representedURL = nil
            loadedURL = nil
            avatarView.image = placeholder
            avatarView.tintColor = .systemGreen
            return
        }

        // SwiftUI/MKMapView 在拖动过程中会高频调用 updateUIView。URL 未变化时保留当前位图，
        // 不重置占位图、不重复下载，避免头像闪烁。
        if loadedURL == url, avatarView.image != nil { return }
        if representedURL == url, imageTask != nil { return }

        imageTask?.cancel()
        imageTask = nil
        representedURL = url
        let cacheKey = url.absoluteString
        if let cached = ImageCacheManager.shared.get(forKey: cacheKey) {
            avatarView.image = cached
            avatarView.tintColor = nil
            loadedURL = url
            return
        }

        // 同一用户更换头像时继续显示旧头像直到新图加载完成；复用的新 Marker 才显示占位图。
        if avatarView.image == nil {
            avatarView.image = placeholder
            avatarView.tintColor = .systemGreen
        }
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, _ in
            guard let data,
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    guard let self, self.representedURL == url else { return }
                    self.representedURL = nil
                    self.imageTask = nil
                }
                return
            }
            ImageCacheManager.shared.set(image, forKey: cacheKey)
            DispatchQueue.main.async {
                guard let self, self.representedURL == url else { return }
                self.avatarView.image = image
                self.avatarView.tintColor = nil
                self.loadedURL = url
                self.imageTask = nil
            }
        }
        imageTask = task
        task.resume()
    }

    func configure(message: NearbyMessagePreview?) {
        guard let message else {
            guard messageBubble.alpha > 0 else { return }
            displayedMessageId = nil
            UIView.animate(withDuration: 1.2) { self.messageBubble.alpha = 0 }
            return
        }
        guard displayedMessageId != message.messageId else { return }
        displayedMessageId = message.messageId
        messageBubble.text = message.text
        let fit = messageBubble.sizeThatFits(CGSize(width: 180, height: 48))
        let width = min(180, max(64, fit.width + 20))
        let height = min(48, max(30, fit.height + 12))
        messageBubble.frame = CGRect(x: (bounds.width - width) / 2, y: -height - 10, width: width, height: height)
        messageBubble.alpha = 0
        messageBubble.transform = CGAffineTransform(scaleX: 0.7, y: 0.7).translatedBy(x: 0, y: 8)
        transform = .identity
        UIView.animate(withDuration: 0.55, delay: 0, usingSpringWithDamping: 0.48, initialSpringVelocity: 0.9) {
            self.messageBubble.alpha = 1
            self.messageBubble.transform = .identity
            self.transform = CGAffineTransform(scaleX: 1.22, y: 0.82)
        } completion: { _ in
            UIView.animate(withDuration: 0.42, delay: 0, usingSpringWithDamping: 0.55, initialSpringVelocity: 0.5) {
                self.transform = .identity
            }
        }
    }
}

// MARK: - 用户地图位置自定义头像 Marker (iOS 27+)
final class UserLocationAnnotationView: MKAnnotationView {
    static let reuseID = "UserLocationMarker"
    
    private let avatarImageView = UIImageView()
    private let pulseLayer = CALayer()
    private var loadedUrlString: String?
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupUI()
    }
    
    private func setupUI() {
        frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        centerOffset = CGPoint(x: 0, y: 0)
        canShowCallout = false
        
        // 动态脉冲光环 (呼吸环动画)
        pulseLayer.frame = bounds.insetBy(dx: -5, dy: -5)
        pulseLayer.cornerRadius = pulseLayer.frame.width / 2
        pulseLayer.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.25).cgColor
        layer.addSublayer(pulseLayer)
        
        // 头像容器图层
        avatarImageView.frame = bounds
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.layer.cornerRadius = 22
        avatarImageView.layer.masksToBounds = true
        avatarImageView.layer.borderWidth = 2.5
        avatarImageView.layer.borderColor = UIColor.white.cgColor
        
        // 高品质投影
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowRadius = 5
        
        addSubview(avatarImageView)
        
        startPulseAnimation()
        setDefaultAvatar()
    }
    
    private func startPulseAnimation() {
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 0.9
        animation.toValue = 1.25
        animation.duration = 1.3
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseLayer.add(animation, forKey: "userPulse")
    }
    
    func configure(with avatarUrlString: String?) {
        guard let avatarUrlString = avatarUrlString, !avatarUrlString.isEmpty else {
            setDefaultAvatar()
            return
        }
        
        if loadedUrlString == avatarUrlString && avatarImageView.image != nil {
            return
        }
        
        loadedUrlString = avatarUrlString
        
        guard let url = NetworkManager.fullUrl(avatarUrlString) else {
            setDefaultAvatar()
            return
        }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if self.loadedUrlString == avatarUrlString, let image = UIImage(data: data) {
                    await MainActor.run {
                        if self.loadedUrlString == avatarUrlString {
                            self.avatarImageView.image = image
                        }
                    }
                }
            } catch {
                if self.loadedUrlString == avatarUrlString {
                    await MainActor.run {
                        if self.loadedUrlString == avatarUrlString {
                            self.setDefaultAvatar()
                        }
                    }
                }
            }
        }
    }
    
    private func setDefaultAvatar() {
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        let icon = UIImage(systemName: "pawprint.fill", withConfiguration: config)?.withTintColor(.white, renderingMode: .alwaysOriginal)
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 44, height: 44))
        let img = renderer.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 44, height: 44))
            
            if let icon = icon {
                let rect = CGRect(x: 11, y: 11, width: 22, height: 22)
                icon.draw(in: rect)
            }
        }
        avatarImageView.image = img
    }
}

extension View {
    @ViewBuilder
    func presentationDetentsIfAvailable() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
        } else {
            self.presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

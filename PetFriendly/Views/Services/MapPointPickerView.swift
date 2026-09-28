import SwiftUI
import MapKit

struct MapPointPickerView: View {
    let title: String
    let onSelect: (CLLocationCoordinate2D, String) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedAddress: String = ""
    @State private var isResolving = false
    // 地址搜索（输入地址自动定位到地图）
    @State private var searchText = ""
    @State private var isSearching = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 地址搜索框：输入地址后自动定位到地图
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(PFColors.textSecondary)
                    TextField(NSLocalizedString("map_picker_search_placeholder", comment: ""), text: $searchText)
                        .font(PFFonts.callout)
                        .autocapitalization(.none)
                        .submitLabel(.search)
                        .onSubmit { searchAddress() }
                    if isSearching {
                        ProgressView().scaleEffect(0.8)
                    } else if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(PFColors.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(PFColors.surfaceSecondary)
                .cornerRadius(PFRadius.md)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

                // 地图（可拖动选点）
                ZStack {
                    Map(coordinateRegion: $region, interactionModes: .all)
                        .onChange(of: region.center.latitude) { _ in
                            let center = region.center
                            selectedCoordinate = center
                            reverseGeocode(center)
                        }
                    
                    // 中心标记大头针
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(PFColors.danger)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                        .offset(y: -18)
                }
                
                // 底部地址信息
                VStack(spacing: 12) {
                    if isResolving {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("map_picker_resolving")
                                .font(PFFonts.caption)
                                .foregroundColor(PFColors.textSecondary)
                        }
                    } else if !selectedAddress.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "location.fill")
                                .foregroundColor(PFColors.primary)
                            Text(selectedAddress)
                                .font(PFFonts.callout)
                                .foregroundColor(PFColors.textPrimary)
                            Spacer()
                        }
                        .padding()
                        .background(PFColors.surfaceSecondary)
                        .cornerRadius(PFRadius.md)
                    }
                    
                    Button(action: {
                        if let coord = selectedCoordinate {
                            onSelect(coord, selectedAddress)
                            dismiss()
                        }
                    }) {
                        Text("map_picker_confirm")
                            .font(PFFonts.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(selectedCoordinate != nil ? PFColors.primary : PFColors.textTertiary.opacity(0.4))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
                    }
                    .disabled(selectedCoordinate == nil)
                }
                .padding()
                .background(PFColors.surface)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common_cancel") { dismiss() }
                        .foregroundColor(PFColors.textSecondary)
                }
            }
            .onAppear {
                // 尝试获取用户当前位置作为初始点
                if let loc = CLLocationManager().location {
                    region.center = loc.coordinate
                    selectedCoordinate = loc.coordinate
                    reverseGeocode(loc.coordinate)
                }
            }
        }
    }
    
    /// 输入地址自动定位到地图
    private func searchAddress() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isSearching = true
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(query) { placemarks, error in
            DispatchQueue.main.async {
                isSearching = false
                guard let coord = placemarks?.first?.location?.coordinate else {
                    UIState.shared.showToast(NSLocalizedString("map_picker_search_fail", comment: ""), style: .warning)
                    return
                }
                withAnimation(.easeInOut(duration: 0.3)) {
                    region.center = coord
                }
                selectedCoordinate = coord
                selectedAddress = query
                reverseGeocode(coord)
            }
        }
    }

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) {
        isResolving = true
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                isResolving = false
                if let placemark = placemarks?.first {
                    let addr = [
                        placemark.administrativeArea,
                        placemark.locality,
                        placemark.subLocality,
                        placemark.thoroughfare,
                        placemark.subThoroughfare
                    ].compactMap { $0 }.joined()
                    selectedAddress = addr.isEmpty ? (placemark.name ?? "") : addr
                } else {
                    selectedAddress = String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
                }
            }
        }
    }
}

// MARK: - 上门服务预约页面

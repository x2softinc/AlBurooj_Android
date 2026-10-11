import SwiftUI
import MapKit

struct IdentifiableCoordinate: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

struct MasjidView: View {
    @State private var masjidInfo: MasjidInfo?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var region: MKCoordinateRegion = MKCoordinateRegion()

    private let accentColor = Color(red: 0.0, green: 0.6, blue: 0.8)

    var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                ProgressView("Loading Masjid info…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let info = masjidInfo {
                masjidCard(info)
                Spacer()
            } else {
                Text("No masjid information available.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .navigationTitle("Masjid Info")
        .task {
            await loadMasjidInfo()
        }
    }

    @ViewBuilder
    private func masjidCard(_ info: MasjidInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "building.2.fill")
                    .font(.title2)
                    .foregroundStyle(accentColor)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(accentColor.opacity(0.15))
                    )
                
                Text(info.masjidName ?? "Unknown Masjid")
                    .font(.title2.weight(.semibold))
                
            }
            VStack(alignment: .leading, spacing: 2) {
                if let address = info.address, !address.isEmpty {
                    infoRow(icon: "mappin.and.ellipse", label: "Address", value: address)
                }
                if let address1 = info.address1, !address1.isEmpty {
                    infoRow(icon: "mappin", label: "Address Line 2", value: address1)
                }
                
                let cityState = [info.city, info.state]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")
                if !cityState.isEmpty {
                    infoRow(icon: "location", label: "City/State", value: cityState)
                }
                if let postal = info.postalCode, !postal.isEmpty {
                    infoRow(icon: "number", label: "Postal Code", value: postal)
                }
                if let country = info.country, !country.isEmpty {
                    infoRow(icon: "globe", label: "Country", value: country)
                }
                if let phone = info.phone, !phone.isEmpty {
                    infoRow(icon: "phone", label: "Phone", value: phone)
                }
                if let email = info.email, !email.isEmpty {
                    infoRow(icon: "envelope", label: "Email", value: email)
                }
                if let url = info.url, !url.isEmpty {
                    infoRow(icon: "link", label: "Website", value: url)
                }
                
            }
             .padding(.leading, 16)
            
            
            Divider()
            
            if info.latitude != 0 || info.longitude != 0 {
                let coordinate = CLLocationCoordinate2D(latitude: info.latitude, longitude: info.longitude)
                let annotation = IdentifiableCoordinate(coordinate: coordinate)
                Map(coordinateRegion: .constant(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )), annotationItems: [annotation]) { item in
                    MapMarker(coordinate: item.coordinate, tint: accentColor)
                }
                .frame(height: 200)
                Button {
                    openInMaps(latitude: info.latitude, longitude: info.longitude, name: info.masjidName ?? "Masjid")
                } label: {
                    Label("Driving Directions", systemImage: "car.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(accentColor)
                        .clipShape(Capsule())
                }
            }
            
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(accentColor.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
            }
        }
    }

    private func loadMasjidInfo() async {
        isLoading = true
        errorMessage = nil
        do {
            let info = try await MasjidService().fetchMasjidInfo()
            masjidInfo = info
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func openInMaps(latitude: Double, longitude: Double, name: String) {
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)))
        destination.name = name
        destination.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

#Preview {
    NavigationStack {
        MasjidView()
    }
}

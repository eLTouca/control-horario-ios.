import SwiftUI

struct ConnectionsView: View {
    private let services: [(String, String, String, String)] = [
        ("Tuya / Smart Life", "house.lodge.fill", "Bombillas, enchufes y sensores compatibles", "Integración pendiente"),
        ("TP-Link Tapo", "video.fill", "Cámaras y dispositivos Tapo", "Integración pendiente"),
        ("Samsung SmartThings", "air.conditioner.horizontal.fill", "Climatización y dispositivos Samsung", "Integración pendiente"),
        ("Apple Casa", "apple.logo", "Accesorios compatibles con HomeKit", "Sin central Apple configurada")
    ]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Conecta las marcas que utilizas en casa. Cada integración se habilitará cuando esté implementada y autorizada.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    ForEach(services, id: \.0) { item in
                        HStack(spacing: 14) {
                            Image(systemName: item.1).font(.title2).foregroundStyle(.blue)
                                .frame(width: 50, height: 50).background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 15))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.0).font(.headline)
                                Text(item.2).font(.caption).foregroundStyle(.secondary)
                                Text(item.3).font(.caption.weight(.semibold)).foregroundStyle(.orange)
                            }
                            Spacer()
                        }
                        .padding(16).background(.background, in: RoundedRectangle(cornerRadius: 20))
                    }
                    Label("No se guardan contraseñas ni se envían datos a ningún servidor en esta versión.", systemImage: "lock.shield")
                        .font(.footnote).foregroundStyle(.secondary).padding(.top, 4)
                }
                .padding(22).frame(maxWidth: 900).frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Conexiones")
        }
    }
}

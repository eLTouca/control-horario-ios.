import SwiftUI

struct ConnectionsView: View {
    private let services: [(String, String, String, String)] = [
        ("Tuya / Smart Life", "house.lodge.fill", "Bombillas, enchufes y sensores compatibles", "Integración pendiente"),
        ("TP-Link Tapo", "video.fill", "Cámara C200 por RTSP local; enchufe P100M pendiente", "Cámara preparada · falta introducir credenciales"),
        ("Samsung SmartThings", "air.conditioner.horizontal.fill", "Climatización y dispositivos Samsung", "Integración pendiente"),
        ("Apple Casa", "apple.logo", "Accesorios compatibles con HomeKit", "Sin central Apple configurada")
    ]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Conecta las marcas que utilizas en casa. Cada integración se habilitará cuando esté implementada y autorizada.")
                        .font(.subheadline).foregroundStyle(AppTheme.muted)
                    ForEach(services, id: \.0) { item in
                        HStack(spacing: 14) {
                            Image(systemName: item.1).font(.title2).foregroundStyle(AppTheme.blue)
                                .frame(width: 50, height: 50).background(AppTheme.blue.opacity(0.14), in: RoundedRectangle(cornerRadius: 15))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.0).font(.headline)
                                Text(item.2).font(.caption).foregroundStyle(AppTheme.muted)
                                Text(item.3).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.muted)
                            }
                            Spacer()
                        }
                        .padding(16).background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 20))
                    }
                    Label("Las credenciales de la cámara se guardan en el Llavero del iPad; no se envían a servidores propios.", systemImage: "lock.shield")
                        .font(.footnote).foregroundStyle(AppTheme.muted).padding(.top, 4)
                }
                .padding(22).frame(maxWidth: 900).frame(maxWidth: .infinity)
            }
            .background(AppTheme.background)
            .navigationTitle("Conexiones")
        }
    }
}

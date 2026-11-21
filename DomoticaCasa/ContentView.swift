import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var home: HomeStore
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            DashboardView().tabItem { Label("Inicio", systemImage: "square.grid.2x2.fill") }.tag(0)
            RoomsView().tabItem { Label("Estancias", systemImage: "house.fill") }.tag(1)
            ScenesView().tabItem { Label("Escenas", systemImage: "sparkles") }.tag(2)
            ConnectionsView().tabItem { Label("Conexiones", systemImage: "dot.radiowaves.left.and.right") }.tag(3)
            SettingsView().tabItem { Label("Ajustes", systemImage: "gearshape.fill") }.tag(4)
        }
        .tint(Color(red: 0.20, green: 0.34, blue: 0.72))
    }
}

struct DashboardView: View {
    @EnvironmentObject private var home: HomeStore
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CASA CONECTADA").font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(.white.opacity(0.75))
                        Text("Hola, bienvenido").font(.largeTitle.bold()).foregroundStyle(.white)
                        Text(home.homeName).font(.title3).foregroundStyle(.white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                    .background(LinearGradient(colors: [Color(red: 0.12, green: 0.20, blue: 0.43), Color(red: 0.25, green: 0.39, blue: 0.73)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28))

                    LazyVGrid(columns: columns, spacing: 14) {
                        MetricCard(title: "Dispositivos activos", value: "\(home.activeCount)", symbol: "power", tint: .green)
                        MetricCard(title: "Dispositivos", value: "\(home.devices.count)", symbol: "lightbulb.2.fill", tint: .blue)
                        MetricCard(title: "Estancias", value: "\(home.rooms.count)", symbol: "door.left.hand.open", tint: .orange)
                        MetricCard(title: "Escenas", value: "\(home.scenes.count)", symbol: "sparkles", tint: .purple)
                    }

                    HStack {
                        Text("Escenas rápidas").font(.title2.bold())
                        Spacer()
                        Text("Ver en Escenas").font(.subheadline.weight(.semibold)).foregroundStyle(.blue)
                    }
                    ForEach(home.scenes) { scene in
                        SceneRow(scene: scene) { home.toggleScene(scene) }
                    }

                    Text("Dispositivos").font(.title2.bold())
                    ForEach(home.devices.prefix(4)) { device in
                        DeviceRow(device: device) { home.toggleDevice(device) }
                    }
                    Text("Modo demostración: los cambios todavía no actúan sobre los equipos físicos.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding(22)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Inicio")
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title2).foregroundStyle(tint).frame(width: 44, height: 44).background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(value).font(.title.bold())
                Text(title).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }
}

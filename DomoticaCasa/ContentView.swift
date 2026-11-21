import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var home: HomeStore
    @State private var selection = 0

    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $selection) {
                DashboardView().tabItem { Label("Inicio", systemImage: "square.grid.2x2.fill") }.tag(0)
                RoomsView().tabItem { Label("Estancias", systemImage: "house.fill") }.tag(1)
                ScenesView().tabItem { Label("Escenas", systemImage: "sparkles") }.tag(2)
                ConnectionsView().tabItem { Label("Conexiones", systemImage: "dot.radiowaves.left.and.right") }.tag(3)
                SettingsView().tabItem { Label("Ajustes", systemImage: "gearshape.fill") }.tag(4)
            }
            .tint(Color(red: 0.20, green: 0.34, blue: 0.72))
            .preferredColorScheme(.dark)
            // Gesto simultáneo: deja que los ScrollView sigan desplazándose
            // verticalmente y solo cambia de pestaña cuando el movimiento
            // es claramente horizontal.
            .simultaneousGesture(
                DragGesture(minimumDistance: 18, coordinateSpace: .local)
                    .onEnded { value in
                        let horizontal = value.translation.width
                        let vertical = value.translation.height
                        let startedAboveTabBar = value.startLocation.y < geometry.size.height - 70

                        guard startedAboveTabBar,
                              abs(horizontal) >= 48,
                              abs(horizontal) > abs(vertical) * 1.25 else { return }

                        let nextSelection = selection + (horizontal < 0 ? 1 : -1)
                        guard (0..<5).contains(nextSelection) else { return }

                        withAnimation(.easeInOut(duration: 0.22)) {
                            selection = nextSelection
                        }
                    }
            )
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var home: HomeStore
    @State private var blindPositions: [String: Double] = ["Salón": 65, "Dormitorio": 100]
    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    LazyVGrid(columns: columns, alignment: .center, spacing: 16) {
                        temperatureCard
                        camerasCard
                        blindsCard
                        lightsCard
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Escenas rápidas").font(.title2.bold())
                            Spacer()
                            Text("Ver en Escenas").font(.subheadline.weight(.semibold)).foregroundStyle(.blue)
                        }
                        ForEach(home.scenes) { scene in
                            SceneRow(scene: scene) { home.toggleScene(scene) }
                        }
                    }

                    Text("Panel de demostración: las cámaras, persianas, sensores y luces todavía no están conectados a los equipos físicos.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
                .padding(22)
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Mi casa")
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("CASA CONECTADA").font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(.white.opacity(0.75))
                Text("Hola, bienvenido").font(.largeTitle.bold()).foregroundStyle(.white)
                Text(home.homeName).font(.title3).foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            Image(systemName: "house.fill")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(24)
        .background(LinearGradient(colors: [Color(red: 0.12, green: 0.20, blue: 0.43), Color(red: 0.25, green: 0.39, blue: 0.73)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28))
    }

    private var temperatureCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeading("Temperatura", symbol: "thermometer.medium")
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("--").font(.system(size: 48, weight: .semibold, design: .rounded))
                Text("°C").font(.title2.weight(.medium))
            }
            Text("Sin sensor conectado").font(.subheadline).foregroundStyle(.secondary)
            Label("Temperatura de la casa", systemImage: "house").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 165, alignment: .leading)
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 22))
    }

    private var camerasCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeading("Cámaras", symbol: "video.fill")
            cameraPreview(name: "Tapo C200 · Entrada")
                .frame(maxWidth: 260)
            Text("Vista en directo pendiente de conectar").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 165, alignment: .leading)
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 22))
    }

    private func cameraPreview(name: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [Color(red: 0.12, green: 0.16, blue: 0.23), Color(red: 0.30, green: 0.36, blue: 0.44)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "video.slash")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.85))
                VStack {
                    HStack {
                        Circle().fill(.red).frame(width: 6, height: 6)
                        Text("SIN SEÑAL").font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
                        Spacer()
                    }
                    Spacer()
                }.padding(8)
            }
            .frame(height: 76)
            Text(name).font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
    }

    private var blindsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeading("Persianas", symbol: "blinds.horizontal")
            ForEach(["Salón", "Dormitorio"], id: \.self) { room in
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(room).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(Int(blindPositions[room] ?? 0))%").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(
                        get: { blindPositions[room] ?? 0 },
                        set: { blindPositions[room] = $0 }
                    ), in: 0...100)
                    HStack {
                        Label("Subir", systemImage: "arrow.up").font(.caption)
                        Spacer()
                        Label("Bajar", systemImage: "arrow.down").font(.caption)
                    }.foregroundStyle(.secondary)
                }
            }
            Text("Controles de muestra").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 22))
    }

    private var lightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeading("Luces", symbol: "lightbulb.fill")
            let lights = home.devices.filter { $0.kind == "Luz" }
            if lights.isEmpty {
                Text("Añade luces desde Estancias").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(lights) { device in
                    HStack(spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(device.isOn ? .yellow : .secondary)
                            .frame(width: 34, height: 34)
                            .background((device.isOn ? Color.yellow : Color.gray).opacity(0.13), in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.name).font(.subheadline.weight(.semibold))
                            Text(device.room).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle(device.name, isOn: Binding(get: { device.isOn }, set: { _ in home.toggleDevice(device) }))
                            .labelsHidden()
                            .tint(.blue)
                    }
                }
            }
            Text("Interruptores de demostración").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 22))
    }

    private func cardHeading(_ title: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(.blue)
            Text(title).font(.headline)
            Spacer()
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

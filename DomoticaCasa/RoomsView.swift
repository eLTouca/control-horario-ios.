import SwiftUI

struct RoomsView: View {
    @EnvironmentObject private var home: HomeStore
    @State private var selectedRoom: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if let roomName = selectedRoom {
                        HStack {
                            Button { selectedRoom = nil } label: { Label("Todas las estancias", systemImage: "chevron.left") }
                            Spacer()
                        }
                        .padding(.bottom, 4)
                        let roomDevices = home.devices(in: roomName)
                        if roomDevices.isEmpty {
                            ContentUnavailableView("Sin dispositivos", systemImage: "lightbulb", description: Text("Todavía no hay equipos en esta estancia."))
                        } else {
                            ForEach(roomDevices) { device in
                                DeviceRow(device: device) { home.toggleDevice(device) }
                            }
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            ForEach(home.rooms) { room in
                                Button { selectedRoom = room.name } label: {
                                    VStack(alignment: .leading, spacing: 14) {
                                        Image(systemName: room.symbol).font(.system(size: 28)).foregroundStyle(AppTheme.blue)
                                            .frame(width: 54, height: 54).background(AppTheme.blue.opacity(0.14), in: RoundedRectangle(cornerRadius: 17))
                                        Text(room.name).font(.headline).foregroundStyle(.white)
                                        Text("\(home.devices(in: room.name).count) dispositivos").font(.caption).foregroundStyle(AppTheme.muted)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(18)
                                    .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 22))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    Text("Los interruptores son de demostración local.").font(.footnote).foregroundStyle(AppTheme.muted).frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(22).frame(maxWidth: 900).frame(maxWidth: .infinity)
            }
            .background(AppTheme.background)
            .navigationTitle(selectedRoom ?? "Estancias")
        }
    }
}

struct DeviceRow: View {
    let device: SmartDevice
    let action: () -> Void
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: device.kind == "Cámara" ? "camera.fill" : device.kind == "Enchufe" ? "powerplug.fill" : "lightbulb.fill")
                .font(.title3).foregroundStyle(AppTheme.blue)
                .frame(width: 44, height: 44).background(AppTheme.blue.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                Text(device.name).font(.headline)
                Text(device.room).font(.caption).foregroundStyle(AppTheme.muted)
            }
            Spacer()
            Toggle(device.name, isOn: Binding(get: { device.isOn }, set: { _ in action() })).labelsHidden()
        }
        .padding(14).background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 18))
    }
}

import SwiftUI

struct SmartDevice: Identifiable {
    let id = UUID()
    var name: String
    var room: String
    var kind: String
    var isOn: Bool
}

struct HomeRoom: Identifiable {
    let id = UUID()
    var name: String
    var symbol: String
    var tint: Color
}

struct HomeScene: Identifiable {
    let id = UUID()
    var name: String
    var subtitle: String
    var symbol: String
    var isActive: Bool
}

@MainActor
final class HomeStore: ObservableObject {
    @Published var homeName = "Mi hogar"
    @Published var devices: [SmartDevice] = [
        SmartDevice(name: "Luz principal", room: "Salón", kind: "Luz", isOn: true),
        SmartDevice(name: "Lámpara auxiliar", room: "Salón", kind: "Luz", isOn: false),
        SmartDevice(name: "Luz techo", room: "Cocina", kind: "Luz", isOn: true),
        SmartDevice(name: "Enchufe TV", room: "Dormitorio", kind: "Enchufe", isOn: false),
        SmartDevice(name: "Cámara", room: "Entrada", kind: "Cámara", isOn: true)
    ]

    @Published var rooms: [HomeRoom] = [
        HomeRoom(name: "Salón", symbol: "sofa.fill", tint: .indigo),
        HomeRoom(name: "Cocina", symbol: "fork.knife", tint: .orange),
        HomeRoom(name: "Dormitorio", symbol: "bed.double.fill", tint: .purple),
        HomeRoom(name: "Entrada", symbol: "door.left.hand.closed", tint: .teal)
    ]

    @Published var scenes: [HomeScene] = [
        HomeScene(name: "Llegar a casa", subtitle: "Iluminación de bienvenida", symbol: "house.fill", isActive: false),
        HomeScene(name: "Buenas noches", subtitle: "Apagar luces seleccionadas", symbol: "moon.stars.fill", isActive: false),
        HomeScene(name: "Salir", subtitle: "Preparar la casa al salir", symbol: "figure.walk", isActive: false)
    ]

    var activeCount: Int { devices.filter(\.isOn).count }

    func toggleDevice(_ device: SmartDevice) {
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[index].isOn.toggle()
    }

    func toggleScene(_ scene: HomeScene) {
        guard let index = scenes.firstIndex(where: { $0.id == scene.id }) else { return }
        let activating = !scenes[index].isActive
        scenes[index].isActive = activating
        if activating {
            switch scene.name {
            case "Buenas noches", "Salir":
                for index in devices.indices where devices[index].kind == "Luz" { devices[index].isOn = false }
            case "Llegar a casa":
                for index in devices.indices where devices[index].room == "Salón" && devices[index].kind == "Luz" { devices[index].isOn = true }
            default: break
            }
        }
    }

    func devices(in room: String) -> [SmartDevice] {
        devices.filter { $0.room == room }
    }
}

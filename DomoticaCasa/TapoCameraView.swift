import SwiftUI
import UIKit
import AVFAudio
import Security
import MobileVLCKit

private enum TapoCameraCredentials {
    private static let service = "es.xeito.domoticacasa.tapo.c200"

    static func load(_ account: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else { return "" }
        return value
    }

    static func save(_ value: String, account: String) {
        let key: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(key as CFDictionary)
        guard let data = value.data(using: .utf8) else { return }
        var item = key
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }
}

@MainActor
private final class TapoCameraPlayer: NSObject, ObservableObject, VLCMediaPlayerDelegate {
    let mediaPlayer = VLCMediaPlayer()
    @Published private(set) var status = "Desconectada"

    override init() {
        super.init()
        mediaPlayer.delegate = self
    }

    func play(username: String, password: String) {
        guard !username.isEmpty, !password.isEmpty else {
            status = "Faltan las credenciales de la cámara"
            return
        }

        status = "Preparando conexión RTSP…"

        // VLC debe tener una sesión de audio válida en iPadOS.
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try audio.setActive(true)
        } catch {
            status = "No se pudo activar el audio: \(error.localizedDescription)"
        }

        // Las credenciales se pasan como opciones RTSP para evitar problemas
        // con caracteres especiales en el usuario o la contraseña de la URL.
        var components = URLComponents()
        components.scheme = "rtsp"
        components.host = "192.168.1.141"
        components.port = 554
        components.path = "/stream1"
        components.user = username
        components.password = password
        guard let url = components.url else {
            status = "Dirección RTSP no válida"
            return
        }

        let media = VLCMedia(url: url)
        media.addOptions([
            ":rtsp-tcp": NSNull(),
            ":network-caching": 1500,
            ":live-caching": 1500
        ])

        // No detener un reproductor que ya está parado: VLC puede emitir una
        // notificación tardía que sobrescriba el estado de este nuevo intento.
        if mediaPlayer.state != .stopped {
            mediaPlayer.stop()
        }
        mediaPlayer.media = media
        status = "Conectando con 192.168.1.141…"
        mediaPlayer.play()
    }

    func stop() {
        mediaPlayer.stop()
        mediaPlayer.drawable = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        status = "Desconectada"
    }

    func mediaPlayerStateChanged(_ aNotification: Notification!) {
        let playerState = mediaPlayer.state
        let stateName: String
        switch playerState {
        case .stopped: stateName = "stopped"
        case .opening: stateName = "opening"
        case .buffering: stateName = "buffering"
        case .playing: stateName = "playing"
        case .paused: stateName = "paused"
        case .error: stateName = "error"
        case .ended: stateName = "ended"
        @unknown default: stateName = "unknown"
        }
        NSLog("DomoticaCasa Tapo VLC state: %@ (%ld)", stateName, playerState.rawValue)

        // No se descartan estados: necesitamos ver también el estado final
        // que VLC comunica después de abrir y almacenar el flujo.

        let newStatus: String
        switch playerState {
        case .opening:
            newStatus = "Abriendo conexión con la cámara…"
        case .buffering:
            newStatus = "Recibiendo vídeo…"
        case .playing:
            newStatus = "Flujo RTSP recibido · VLC reproduciendo"
        case .paused:
            newStatus = "Reproducción pausada"
        case .error:
            newStatus = "VLC ha notificado un error de reproducción (estado 7). No confirma un problema de contraseña."
        case .ended:
            newStatus = "La cámara ha terminado el flujo"
        case .stopped:
            newStatus = "VLC ha detenido el flujo (estado 0)."
        @unknown default:
            newStatus = "Estado de cámara: \(mediaPlayer.state.rawValue)"
        }
        DispatchQueue.main.async { [weak self] in
            self?.status = newStatus
        }
    }

    func mediaPlayerTimeChanged(_ aNotification: Notification!) {
        // El estado de reproducción se comunica mediante mediaPlayerStateChanged.
    }
}

private final class TapoVideoView: UIView {
    var onAttach: ((UIView) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            onAttach?(self)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if window != nil {
            onAttach?(self)
        }
    }
}

private struct TapoVideoSurface: UIViewRepresentable {
    let player: VLCMediaPlayer

    func makeUIView(context: Context) -> UIView {
        let view = TapoVideoView()
        view.backgroundColor = .black
        view.isOpaque = true
        view.onAttach = { [weak player] videoView in
            player?.drawable = videoView
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        player.drawable = uiView
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        (uiView as? TapoVideoView)?.onAttach = nil
    }
}

struct TapoCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = TapoCameraPlayer()
    @State private var username = TapoCameraCredentials.load("username")
    @State private var password = TapoCameraCredentials.load("password")

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                TapoVideoSurface(player: camera.mediaPlayer)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Cuenta de cámara Tapo").font(.headline)
                    Text("Introduce el usuario y la contraseña de cámara configurados en la aplicación Tapo. No son los datos de tu cuenta TP-Link.")
                        .font(.footnote).foregroundStyle(AppTheme.muted)
                    TextField("Usuario de cámara", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                    SecureField("Contraseña de cámara", text: $password)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        TapoCameraCredentials.save(username, account: "username")
                        TapoCameraCredentials.save(password, account: "password")
                        camera.play(username: username, password: password)
                    } label: {
                        Label("Conectar con la cámara", systemImage: "video.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.blue)
                    .disabled(username.isEmpty || password.isEmpty)
                    Text(camera.status)
                        .font(.caption).foregroundStyle(AppTheme.muted)
                }
                .frame(maxWidth: 620, alignment: .leading)
                Spacer(minLength: 0)
            }
            .padding(22)
            .background(AppTheme.background)
            .navigationTitle("Tapo C200")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .onDisappear { camera.stop() }
        }
        .tint(AppTheme.blue)
    }
}

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


private final class TapoVLCLogger: NSObject, VLCLogging {
    var level: VLCLogLevel = .debug
    var onMessage: ((String) -> Void)?

    func handleMessage(_ message: String, logLevel: VLCLogLevel, context: VLCLogContext?) {
        let line = message
        DispatchQueue.main.async { [weak self] in
            self?.onMessage?(line)
        }
    }
}

@MainActor
private final class TapoCameraPlayer: NSObject, ObservableObject, VLCMediaPlayerDelegate {
    @Published private(set) var mediaPlayer = VLCMediaPlayer()
    @Published var status: String = "Desconectada"
    @Published var diagnosticLog: String = ""

    private let vlcLogger = TapoVLCLogger()

    override init() {
        super.init()

        mediaPlayer.delegate = self

        vlcLogger.onMessage = { [weak self] message in
            guard let self else { return }
            self.appendDiagnostic(message)
        }

        mediaPlayer.delegate = self
        mediaPlayer.libraryInstance.loggers = [vlcLogger]

        appendDiagnostic("Registrador interno de VLC activado (DEBUG).")
    }

    private func appendDiagnostic(_ message: String) {
        var safeMessage = message

        if !usernameForLog.isEmpty {
            safeMessage = safeMessage.replacingOccurrences(
                of: usernameForLog, with: "[usuario oculto]"
            )
        }

        if !passwordForLog.isEmpty {
            safeMessage = safeMessage.replacingOccurrences(
                of: passwordForLog, with: "[contraseña oculta]"
            )
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        let line = "[\(formatter.string(from: Date()))] \(safeMessage)"
        diagnosticLog += line + "\n"

        if diagnosticLog.count > 14000 {
            diagnosticLog = String(diagnosticLog.suffix(12000))
        }
    }

    private var usernameForLog = ""
    private var passwordForLog = ""

    nonisolated func mediaPlayerStateChanged(_ aNotification: Notification!) {
        guard let player = aNotification.object as? VLCMediaPlayer else { return }
        let currentState = player.state

        Task { @MainActor [weak self] in
            guard let self = self else { return }

            switch currentState {
            case .opening:
                self.status = "Abriendo conexión con la cámara..."
            case .buffering:
                self.status = "Conexión abierta: cargando vídeo..."
            case .playing:
                self.status = "Reproduciendo cámara"
            case .error:
                self.status = "ERROR de VLC: no se pudo reproducir el vídeo"
            case .ended:
                self.status = "La transmisión ha terminado"
            case .paused:
                self.status = "Reproducción pausada"
            case .stopped:
                self.status = "Reproductor detenido"
            default:
                self.status = "Estado VLC: \(currentState.rawValue)"
            }

            self.appendDiagnostic("Estado del reproductor: \(currentState.rawValue)")
        }
    }

    func play(username: String, password: String) {
        usernameForLog = username
        passwordForLog = password

        status = "Conectando con la cámara..."
        appendDiagnostic("Solicitada conexión RTSP a 192.168.1.141:554/stream2")

        mediaPlayer.stop()
        let playerOptions = [
            "--rtsp-user=\(username)",
            "--rtsp-pwd=\(password)",
            "--rtsp-tcp",
            "--network-caching=1500",
            "--avcodec-hw=none"
        ]
        let authenticatedPlayer = VLCMediaPlayer(options: playerOptions)
        authenticatedPlayer.delegate = self
        authenticatedPlayer.libraryInstance.loggers = [vlcLogger]
        mediaPlayer = authenticatedPlayer

        var components = URLComponents()
        components.scheme = "rtsp"
        components.host = "192.168.1.141"
        components.port = 554
        components.path = "/stream2"

        guard let url = components.url else {
            appendDiagnostic("ERROR: No se pudo construir la dirección RTSP.")
            return
        }

        let media = VLCMedia(url: url)
        mediaPlayer.media = media
        mediaPlayer.play()
    }

    func stop() {
        appendDiagnostic("Se ha solicitado detener el reproductor.")
        status = "Desconectada"
        mediaPlayer.stop()
        mediaPlayer.drawable = nil
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

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Diagnóstico de VLC")
                                .font(.headline)
                            Spacer()
                            Button {
                                UIPasteboard.general.string = camera.diagnosticLog
                            } label: {
                                Label("Copiar", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                            .disabled(camera.diagnosticLog.isEmpty)
                        }

                        ScrollView {
                            Text(camera.diagnosticLog.isEmpty
                                 ? "Esperando mensajes de VLC..."
                                 : camera.diagnosticLog)
                                .font(.system(.caption2, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .padding(8)
                        }
                        .frame(height: 170)
                        .background(.black.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

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

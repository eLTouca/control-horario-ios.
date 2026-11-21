import SwiftUI
import UIKit
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
private final class TapoCameraPlayer: ObservableObject {
    let mediaPlayer = VLCMediaPlayer()

    func play(username: String, password: String) {
        var components = URLComponents()
        components.scheme = "rtsp"
        components.host = "192.168.1.141"
        components.port = 554
        components.path = "/stream1"
        components.user = username
        components.password = password
        guard let url = components.url else { return }
        let media = VLCMedia(url: url)
        media.addOptions([
            "rtsp-tcp": true,
            "network-caching": 1000,
            "avcodec-hw": "none"
        ])
        mediaPlayer.media = media
        mediaPlayer.play()
    }

    func stop() {
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
    @State private var isConnecting = false

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
                        isConnecting = true
                    } label: {
                        Label("Conectar con la cámara", systemImage: "video.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.blue)
                    .disabled(username.isEmpty || password.isEmpty)
                    Text(isConnecting
                         ? "Conectando a 192.168.1.141… Si no aparece vídeo, comprueba que la cuenta de cámara y RTSP estén habilitados en Tapo."
                         : "Cámara local · 192.168.1.141 · RTSP")
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

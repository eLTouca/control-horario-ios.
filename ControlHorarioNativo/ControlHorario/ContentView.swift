import SwiftUI
import WebKit
import CoreLocation
import UIKit

struct ContentView: View {
    @StateObject private var location = NativeLocationManager()

    var body: some View {
        ZStack {
            ControlHorarioWebView(locationManager: location)
                .ignoresSafeArea(edges: .bottom)
            if location.showPermissionHelp {
                VStack(spacing: 12) {
                    Image(systemName: "location.circle.fill").font(.system(size: 34)).foregroundStyle(.blue)
                    Text("Permite el acceso a tu ubicación")
                        .font(.headline)
                    Text("Para contar las horas con la app en segundo plano, permite el acceso a la ubicación en todo momento. En Ajustes del iPhone, selecciona Ubicación > Siempre y activa Ubicación precisa.")
                        .multilineTextAlignment(.center).font(.subheadline)
                    Button("Abrir Ajustes") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Cerrar") { location.showPermissionHelp = false }
                        .buttonStyle(.bordered)
                }
                .padding(22).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .padding(28)
            }
        }
        .tint(.blue)
    }
}

struct ControlHorarioWebView: UIViewRepresentable {
    let locationManager: NativeLocationManager

    func makeCoordinator() -> Coordinator { Coordinator(locationManager: locationManager) }

    func makeUIView(context: Context) -> WKWebView {
        let content = WKUserContentController()
        content.add(context.coordinator, name: "location")
        content.add(context.coordinator, name: "pdf")
        content.add(context.coordinator, name: "aeat")
        let config = WKWebViewConfiguration()
        config.userContentController = content
        let web = WKWebView(frame: .zero, configuration: config)
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.isOpaque = false
        web.backgroundColor = UIColor.systemBackground
        context.coordinator.webView = web
        locationManager.onUpdate = { [weak web] lat, lon, accuracy in
            let js = "window.nativeLocationReceived && window.nativeLocationReceived(\(lat),\(lon),\(accuracy));"
            DispatchQueue.main.async { web?.evaluateJavaScript(js) }
        }
        locationManager.onError = { [weak web] code in
            let js = "window.nativeLocationError && window.nativeLocationError(\(code));"
            DispatchQueue.main.async { web?.evaluateJavaScript(js) }
        }
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: nil) {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKScriptMessageHandler {
        let locationManager: NativeLocationManager
        weak var webView: WKWebView?
        init(locationManager: NativeLocationManager) { self.locationManager = locationManager }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "pdf" {
                handlePDFMessage(message.body)
                return
            }
            if message.name == "aeat" {
                handleAEATMessage(message.body)
                return
            }
            guard let command = message.body as? String else { return }
            switch command {
            case "once": locationManager.requestSingleLocation()
            case "watch": locationManager.startWatching()
            case "stop": locationManager.stopWatching()
            default: break
            }
        }

        private func handleAEATMessage(_ body: Any) {
            guard let payload = body as? [String: Any],
                  let xml = payload["xml"] as? String,
                  !xml.isEmpty,
                  let webView else { return }

            // Sesión efímera: no persiste cookies ni caché de la petición.
            guard let url = URL(string: "https://www2.agenciatributaria.gob.es/wlpl/PRET-R200/mc") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 45
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.setValue("text/xml, application/xml, */*", forHTTPHeaderField: "Accept")

            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
            guard let encodedXML = xml.addingPercentEncoding(withAllowedCharacters: allowed) else {
                sendAEATResult(["ok": false, "error": "No se pudieron preparar los datos para la AEAT."], to: webView)
                return
            }
            request.httpBody = "EJER=2026&PER=0&F01=\(encodedXML)".data(using: .utf8)

            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.httpCookieStorage = nil
            configuration.httpCookieAcceptPolicy = .never
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            let session = URLSession(configuration: configuration)
            session.dataTask(with: request) { [weak self, weak webView] data, response, error in
                guard let self, let webView else { return }
                if let error {
                    self.sendAEATResult(["ok": false, "error": "Error de conexión con la AEAT: \(error.localizedDescription)"], to: webView)
                    session.finishTasksAndInvalidate()
                    return
                }
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard let data, let responseXML = String(data: data, encoding: .utf8), !responseXML.isEmpty else {
                    self.sendAEATResult(["ok": false, "error": "La AEAT ha devuelto una respuesta vacía (HTTP \(status))."], to: webView)
                    session.finishTasksAndInvalidate()
                    return
                }
                if status == 400 {
                    self.sendAEATResult(["ok": false, "error": "La AEAT ha rechazado los datos enviados (HTTP 400). Revisa los datos fiscales introducidos."], to: webView)
                } else if !(200...299).contains(status) {
                    self.sendAEATResult(["ok": false, "error": "El servicio de la AEAT no está disponible (HTTP \(status))."], to: webView)
                } else {
                    self.sendAEATResult(["ok": true, "xml": responseXML], to: webView)
                }
                session.finishTasksAndInvalidate()
            }.resume()
        }

        private func sendAEATResult(_ result: [String: Any], to webView: WKWebView) {
            guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.fragmentsAllowed]),
                  let json = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                webView.evaluateJavaScript("window.aeatResult && window.aeatResult(\(json));")
            }
        }

        private func handlePDFMessage(_ body: Any) {
            guard let payload = body as? [String: Any],
                  let action = payload["action"] as? String,
                  let filename = payload["filename"] as? String,
                  let base64 = payload["data"] as? String,
                  let data = Data(base64Encoded: base64),
                  let webView,
                  let presenter = webView.parentViewController else { return }

            let safeName = URL(fileURLWithPath: filename).lastPathComponent
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(safeName)
            do {
                try data.write(to: fileURL, options: .atomic)
            } catch {
                return
            }

            DispatchQueue.main.async {
                if action == "save" {
                    let picker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
                    picker.shouldShowFileExtensions = true
                    presenter.present(picker, animated: true)
                } else if action == "share" {
                    let activity = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                    if let popover = activity.popoverPresentationController {
                        popover.sourceView = webView
                        popover.sourceRect = CGRect(x: webView.bounds.midX, y: webView.bounds.midY, width: 0, height: 0)
                        popover.permittedArrowDirections = []
                    }
                    presenter.present(activity, animated: true)
                }
            }
        }
    }
}

final class NativeLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var mode: Mode = .single
    private var requestedAlways = false
    @Published var showPermissionHelp = false
    var onUpdate: ((Double, Double, Double) -> Void)?
    var onError: ((Int) -> Void)?
    private enum Mode: Equatable { case single, watching }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.activityType = .other
        manager.pausesLocationUpdatesAutomatically = false
    }

    func requestSingleLocation() {
        mode = .single
        requestPermissionAndStart()
    }

    func startWatching() {
        mode = .watching
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        requestPermissionAndStart()
    }

    func stopWatching() {
        mode = .single
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    private func requestPermissionAndStart() {
        guard CLLocationManager.locationServicesEnabled() else { onError?(2); return }
        switch manager.authorizationStatus {
        case .notDetermined:
            if mode == .watching {
                requestedAlways = true
                manager.requestAlwaysAuthorization()
            } else {
                manager.requestWhenInUseAuthorization()
            }
        case .authorizedAlways:
            manager.startUpdatingLocation()
        case .authorizedWhenInUse:
            if mode == .watching {
                requestedAlways = true
                manager.requestAlwaysAuthorization()
            } else {
                manager.startUpdatingLocation()
            }
        case .denied, .restricted:
            showPermissionHelp = true
            onError?(1)
        @unknown default:
            onError?(2)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            DispatchQueue.main.async { self.showPermissionHelp = false }
            if mode == .watching {
                manager.allowsBackgroundLocationUpdates = true
                manager.startUpdatingLocation()
            } else {
                manager.startUpdatingLocation()
            }
        case .authorizedWhenInUse:
            if mode == .watching && !requestedAlways {
                requestedAlways = true
                manager.requestAlwaysAuthorization()
            } else if mode == .single {
                manager.startUpdatingLocation()
            }
            DispatchQueue.main.async { self.showPermissionHelp = false }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.showPermissionHelp = true
                self.onError?(1)
            }
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        onUpdate?(location.coordinate.latitude, location.coordinate.longitude, location.horizontalAccuracy)
        if mode == .single { manager.stopUpdatingLocation() }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onError?(2)
    }
}

private extension UIView {
    var parentViewController: UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIViewController { return controller }
            responder = current.next
        }
        return nil
    }
}

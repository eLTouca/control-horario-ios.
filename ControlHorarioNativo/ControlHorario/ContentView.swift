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
                    Text("Para fijar el centro de trabajo, permite que Control horario use tu ubicación mientras utilizas la app. Puedes cambiarlo después en Ajustes del iPhone.")
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
        let config = WKWebViewConfiguration()
        config.userContentController = content
        let web = WKWebView(frame: .zero, configuration: config)
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.isOpaque = false
        web.backgroundColor = UIColor.systemBackground
        context.coordinator.webView = web
        web.uiDelegate = context.coordinator
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

    final class Coordinator: NSObject, WKScriptMessageHandler, WKUIDelegate {
        let locationManager: NativeLocationManager
        weak var webView: WKWebView?
        init(locationManager: NativeLocationManager) { self.locationManager = locationManager }

        // WKWebView no abre automáticamente enlaces con target="_blank".
        // Abrimos esos enlaces externos en Safari.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            guard navigationAction.targetFrame == nil,
                  let url = navigationAction.request.url else { return nil }
            UIApplication.shared.open(url)
            return nil
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let command = message.body as? String else { return }
            switch command {
            case "once": locationManager.requestSingleLocation()
            case "watch": locationManager.startWatching()
            case "stop": locationManager.stopWatching()
            default: break
            }
        }
    }
}

final class NativeLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var mode: Mode = .single
    @Published var showPermissionHelp = false
    var onUpdate: ((Double, Double, Double) -> Void)?
    var onError: ((Int) -> Void)?
    private enum Mode: Equatable { case single, watching }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
    }

    func requestSingleLocation() {
        mode = .single
        requestPermissionAndStart()
    }

    func startWatching() {
        mode = .watching
        requestPermissionAndStart()
    }

    func stopWatching() { manager.stopUpdatingLocation() }

    private func requestPermissionAndStart() {
        guard CLLocationManager.locationServicesEnabled() else { onError?(2); return }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            showPermissionHelp = true
            onError?(1)
        @unknown default:
            onError?(2)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
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

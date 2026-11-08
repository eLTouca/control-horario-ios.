import SwiftUI
import WebKit
import CoreLocation
import UIKit
import Vision

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
        content.add(context.coordinator, name: "payrollPhoto")
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

    final class Coordinator: NSObject, WKScriptMessageHandler, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let locationManager: NativeLocationManager
        weak var webView: WKWebView?
        private var activeImagePicker: UIImagePickerController?
        init(locationManager: NativeLocationManager) { self.locationManager = locationManager }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "pdf" {
                handlePDFMessage(message.body)
                return
            }
            if message.name == "payrollPhoto" {
                presentPayrollSourcePicker()
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

        // Selección de nómina y reconocimiento OCR completamente local en el iPhone.
        private static func topViewController() -> UIViewController? {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let root = scenes.flatMap { $0.windows }.first(where: { $0.isKeyWindow })?.rootViewController
            var top = root
            while let presented = top?.presentedViewController { top = presented }
            if let nav = top as? UINavigationController { return nav.visibleViewController ?? nav }
            if let tab = top as? UITabBarController { return tab.selectedViewController ?? tab }
            return top
        }

        private func presentPayrollSourcePicker() {
            guard let webView, let presenter = Self.topViewController() else {
                sendPayrollOCRResult(["ok": false, "error": "No se pudo abrir el selector. Cierra y vuelve a abrir la app."])
                return
            }
            let alert = UIAlertController(title: "Añadir nómina", message: "Haz una foto o selecciona una imagen de tu galería.", preferredStyle: .actionSheet)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                alert.addAction(UIAlertAction(title: "Hacer una foto", style: .default) { [weak self] _ in
                    self?.presentImagePicker(source: .camera)
                })
            }
            alert.addAction(UIAlertAction(title: "Elegir de la galería", style: .default) { [weak self] _ in
                self?.presentImagePicker(source: .photoLibrary)
            })
            alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
            if let popover = alert.popoverPresentationController {
                popover.sourceView = webView
                popover.sourceRect = CGRect(x: webView.bounds.midX, y: webView.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            DispatchQueue.main.async { presenter.present(alert, animated: true) }
        }

        private func presentImagePicker(source: UIImagePickerController.SourceType) {
            guard let webView, let presenter = Self.topViewController() else {
                sendPayrollOCRResult(["ok": false, "error": "No se pudo abrir la cámara o galería."])
                return
            }
            guard UIImagePickerController.isSourceTypeAvailable(source) else {
                sendPayrollOCRResult(["ok": false, "error": source == .camera ? "La cámara no está disponible." : "La galería no está disponible."])
                return
            }
            let picker = UIImagePickerController()
            picker.sourceType = source
            picker.delegate = self
            picker.allowsEditing = false
            activeImagePicker = picker
            DispatchQueue.main.async { presenter.present(picker, animated: true) }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            activeImagePicker = nil
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = (info[.originalImage] as? UIImage)
            picker.dismiss(animated: true) { [weak self] in
                self?.activeImagePicker = nil
                guard let image else {
                    self?.sendPayrollOCRResult(["ok": false, "error": "No se pudo abrir la imagen seleccionada."])
                    return
                }
                self?.recognizePayrollText(in: image)
            }
        }

        private func recognizePayrollText(in image: UIImage) {
            guard let cgImage = image.cgImage else {
                sendPayrollOCRResult(["ok": false, "error": "La imagen no tiene un formato compatible."])
                return
            }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.automaticallyDetectsLanguage = true
                request.recognitionLanguages = ["es-ES"]
                request.usesLanguageCorrection = true
                do {
                    try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
                    let lines = (request.results ?? []).compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }
                    let recognizedText = lines.joined(separator: "\n")
                    DispatchQueue.main.async {
                        guard !recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            self?.sendPayrollOCRResult(["ok": false, "error": "No se ha podido leer el texto. Prueba con una foto más nítida, bien iluminada y con la nómina completa."])
                            return
                        }
                        self?.sendPayrollOCRResult(["ok": true, "text": recognizedText])
                    }
                } catch {
                    DispatchQueue.main.async {
                        self?.sendPayrollOCRResult(["ok": false, "error": "No se pudo leer la nómina: \(error.localizedDescription)"])
                    }
                }
            }
        }

        private func sendPayrollOCRResult(_ result: [String: Any]) {
            guard let webView,
                  let data = try? JSONSerialization.data(withJSONObject: result, options: [.fragmentsAllowed]),
                  let json = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                webView.evaluateJavaScript("window.payrollOCRResult && window.payrollOCRResult(\(json));")
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
    private let askedForAlwaysKey = "ControlHorarioAskedForAlwaysLocation"
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
            // El primer permiso se solicita una sola vez. iOS guarda la elección.
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways:
            manager.startUpdatingLocation()
        case .authorizedWhenInUse:
            if mode == .watching && !UserDefaults.standard.bool(forKey: askedForAlwaysKey) {
                UserDefaults.standard.set(true, forKey: askedForAlwaysKey)
                manager.requestAlwaysAuthorization()
            } else {
                manager.startUpdatingLocation()
                if mode == .watching {
                    DispatchQueue.main.async { self.showPermissionHelp = true }
                }
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
            if mode == .watching { manager.allowsBackgroundLocationUpdates = true }
            manager.startUpdatingLocation()
        case .authorizedWhenInUse:
            if mode == .watching && !UserDefaults.standard.bool(forKey: askedForAlwaysKey) {
                UserDefaults.standard.set(true, forKey: askedForAlwaysKey)
                manager.requestAlwaysAuthorization()
            } else {
                manager.startUpdatingLocation()
                DispatchQueue.main.async { self.showPermissionHelp = (mode == .watching) }
            }
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

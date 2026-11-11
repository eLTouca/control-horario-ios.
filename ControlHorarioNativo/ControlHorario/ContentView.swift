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
        content.add(context.coordinator, name: "backup")
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
        locationManager.onGeofenceEvent = { [weak web] state, timestamp in
            let js = "window.nativeGeofenceReady && window.nativeGeofenceEvent ? (window.nativeGeofenceEvent('\(state)', \(timestamp * 1000)), true) : false;"
            DispatchQueue.main.async {
                web?.evaluateJavaScript(js) { result, error in
                    if error == nil, let delivered = result as? Bool, delivered { locationManager.acknowledgeGeofenceEvent(state, timestamp: timestamp) }
                }
            }
        }
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: nil) {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKScriptMessageHandler, UIDocumentPickerDelegate {
        let locationManager: NativeLocationManager
        weak var webView: WKWebView?
        private let backupBookmarkKey = "ControlHorario.backupBookmark"
        private var pendingBackupData: Data?

        init(locationManager: NativeLocationManager) {
            self.locationManager = locationManager
            super.init()
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "backup" {
                handleBackupMessage(message.body)
                return
            }
            if message.name == "pdf" {
                handlePDFMessage(message.body)
                return
            }
            if let command = message.body as? String {
                if command == "once" { locationManager.requestSingleLocation() }
                else if command == "stop" { locationManager.stopWatching() }
                else if command == "sync" {
                    for event in locationManager.pendingGeofenceEvents() {
                        let js = "window.nativeGeofenceReady && window.nativeGeofenceEvent ? (window.nativeGeofenceEvent('\\(event.state)', \\(event.timestamp * 1000)), true) : false;"
                        self.webView?.evaluateJavaScript(js) { result, error in
                            if error == nil, let delivered = result as? Bool, delivered {
                                self.locationManager.acknowledgeGeofenceEvent(event.state, timestamp: event.timestamp)
                            }
                        }
                    }
                }
                return
            }
            if let payload = message.body as? [String: Any],
               payload["action"] as? String == "watch",
               let lat = payload["lat"] as? Double,
               let lng = payload["lng"] as? Double,
               let radius = payload["radius"] as? Double {
                locationManager.startWatching(latitude: lat, longitude: lng, radius: radius)
            }
        }

        private func handleBackupMessage(_ body: Any) {
            guard let payload = body as? [String: Any],
                  let action = payload["action"] as? String,
                  let webView,
                  let presenter = webView.parentViewController else { return }

            if action == "choose", let json = payload["data"] as? String {
                pendingBackupData = Data(json.utf8)
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("copia-seguridad-control-horario.json")
                do {
                    try pendingBackupData?.write(to: tempURL, options: .atomic)
                    let picker = UIDocumentPickerViewController(forExporting: [tempURL], asCopy: true)
                    picker.delegate = self
                    picker.shouldShowFileExtensions = true
                    presenter.present(picker, animated: true)
                } catch {
                    notifyBackup("No se pudo preparar la copia de seguridad.")
                }
            } else if action == "update", let json = payload["data"] as? String {
                writeBackup(Data(json.utf8))
            }
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            do {
                let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(bookmark, forKey: backupBookmarkKey)
                if let data = pendingBackupData {
                    try writeBackupData(data, to: url)
                    notifyBackup("Copia de seguridad creada. Se actualizará automáticamente al guardar cambios.")
                }
            } catch {
                notifyBackup("No se pudo guardar la ubicación de la copia. Inténtalo de nuevo.")
            }
            pendingBackupData = nil
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            pendingBackupData = nil
        }

        private func writeBackup(_ data: Data) {
            guard let bookmark = UserDefaults.standard.data(forKey: backupBookmarkKey) else { return }
            var stale = false
            do {
                let url = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
                if stale {
                    let refreshed = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
                    UserDefaults.standard.set(refreshed, forKey: backupBookmarkKey)
                }
                try writeBackupData(data, to: url)
            } catch {
                notifyBackup("No se pudo actualizar la copia de seguridad. Vuelve a elegir su ubicación.")
            }
        }

        private func writeBackupData(_ data: Data, to url: URL) throws {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            var coordinationError: NSError?
            var writeError: Error?
            NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { destination in
                do { try data.write(to: destination, options: .atomic) }
                catch { writeError = error }
            }
            if let coordinationError { throw coordinationError }
            if let writeError { throw writeError }
        }

        private func notifyBackup(_ message: String) {
            let escaped = message.replacingOccurrences(of: "\\\\", with: "\\\\\\\\")
                .replacingOccurrences(of: "'", with: "\\\\'")
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript("window.toast && window.toast('\(escaped)')")
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
    private let regionID = "control-horario-centro"
    private var mode: Mode = .single
    private var isGeofenceActive = false
    private var requestedAlways = false
    private var pendingRegion: CLCircularRegion?
    @Published var showPermissionHelp = false
    var onUpdate: ((Double, Double, Double) -> Void)?
    var onError: ((Int) -> Void)?
    var onGeofenceEvent: ((String, TimeInterval) -> Void)?
    private let pendingEventsKey = "ControlHorario.pendingGeofenceEvents"

    struct PendingGeofenceEvent {
        let state: String
        let timestamp: TimeInterval
    }

    // Read without deleting: each event is removed only after the WebView
    // confirms that JavaScript processed it successfully.
    func pendingGeofenceEvents() -> [PendingGeofenceEvent] {
        let stored = UserDefaults.standard.array(forKey: pendingEventsKey) as? [[String: Any]] ?? []
        return stored.compactMap { item in
            guard let state = item["state"] as? String,
                  let timestamp = item["timestamp"] as? TimeInterval else { return nil }
            return PendingGeofenceEvent(state: state, timestamp: timestamp)
        }
    }

    func acknowledgeGeofenceEvent(_ state: String, timestamp: TimeInterval) {
        var stored = UserDefaults.standard.array(forKey: pendingEventsKey) as? [[String: Any]] ?? []
        stored.removeAll {
            ($0["state"] as? String) == state &&
            abs(($0["timestamp"] as? TimeInterval ?? 0) - timestamp) < 0.01
        }
        UserDefaults.standard.set(stored, forKey: pendingEventsKey)
    }

    private func queueGeofenceEvent(_ state: String) {
        let timestamp = Date().timeIntervalSince1970
        var stored = UserDefaults.standard.array(forKey: pendingEventsKey) as? [[String: Any]] ?? []
        stored.append(["state": state, "timestamp": timestamp])
        UserDefaults.standard.set(stored, forKey: pendingEventsKey)
        onGeofenceEvent?(state, timestamp)
    }
    private enum Mode { case single, geofence }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .other
        manager.pausesLocationUpdatesAutomatically = true
    }

    func requestSingleLocation() {
        mode = .single
        guard CLLocationManager.locationServicesEnabled() else { onError?(2); return }
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted: showPermissionHelp = true; onError?(1)
        @unknown default: onError?(2)
        }
    }

    func startWatching(latitude: Double, longitude: Double, radius: Double) {
        mode = .geofence
        isGeofenceActive = true
        guard CLLocationManager.locationServicesEnabled(),
              CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            onError?(2); return
        }
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            radius: min(1000, max(100, radius)),
            identifier: regionID
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        pendingRegion = region
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            requestedAlways = true
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            beginMonitoring(region)
        case .denied, .restricted:
            showPermissionHelp = true
            onError?(1)
        @unknown default: onError?(2)
        }
    }

    private func beginMonitoring(_ region: CLCircularRegion) {
        guard isGeofenceActive else { return }
        for old in manager.monitoredRegions where old.identifier == regionID {
            manager.stopMonitoring(for: old)
        }
        manager.startMonitoring(for: region)
    }

    func stopWatching() {
        mode = .single
        isGeofenceActive = false
        pendingRegion = nil
        for region in manager.monitoredRegions where region.identifier == regionID {
            manager.stopMonitoring(for: region)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            DispatchQueue.main.async { self.showPermissionHelp = false }
            if isGeofenceActive, let region = pendingRegion { beginMonitoring(region) }
            else if mode == .single { manager.requestLocation() }
        case .authorizedWhenInUse:
            if isGeofenceActive {
                if !requestedAlways {
                    requestedAlways = true
                    manager.requestAlwaysAuthorization()
                } else {
                    DispatchQueue.main.async { self.showPermissionHelp = true }
                }
            } else if mode == .single {
                manager.requestLocation()
                DispatchQueue.main.async { self.showPermissionHelp = false }
            }
        case .denied, .restricted:
            DispatchQueue.main.async { self.showPermissionHelp = true; self.onError?(1) }
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        manager.requestState(for: region)
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        // Core Location may relaunch the app for a region event. Do not require
        // an in-memory flag: it is reset when iOS creates a new process.
        guard region.identifier == regionID else { return }
        if state == .inside { queueGeofenceEvent("state-inside") }
        else if state == .outside { queueGeofenceEvent("state-outside") }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if region.identifier == regionID { queueGeofenceEvent("enter") }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if region.identifier == regionID { queueGeofenceEvent("exit") }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard mode == .single, let location = locations.last else { return }
        onUpdate?(location.coordinate.latitude, location.coordinate.longitude, location.horizontalAccuracy)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onError?(2)
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
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

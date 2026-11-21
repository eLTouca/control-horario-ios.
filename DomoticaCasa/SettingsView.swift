import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var home: HomeStore
    @State private var remoteAccess = false
    @State private var familySync = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Hogar") {
                    TextField("Nombre del hogar", text: $home.homeName)
                }
                Section("Acceso") {
                    Toggle("Acceso remoto", isOn: $remoteAccess)
                    Text("El acceso remoto requiere integrar los servicios oficiales de cada fabricante. Este ajuste es informativo y todavía no habilita conexiones externas.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Familia") {
                    Toggle("Sincronización familiar con iCloud", isOn: $familySync)
                    Text("La sincronización familiar se añadirá en una fase posterior. iCloud sincronizará ajustes y configuración, no hará de puente para controlar equipos.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Acerca de") {
                    LabeledContent("Aplicación", value: "Domótica Casa")
                    LabeledContent("Versión", value: "0.1 — Base inicial")
                    LabeledContent("Dispositivo", value: "iPad")
                }
            }
            .scrollContentBackground(.hidden).background(AppTheme.background)
            .tint(AppTheme.blue)
            .frame(maxWidth: 900).navigationTitle("Ajustes")
        }
    }
}

import SwiftUI

struct ScenesView: View {
    @EnvironmentObject private var home: HomeStore
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Un toque para adaptar la casa a cada momento.")
                        .font(.subheadline).foregroundStyle(AppTheme.muted)
                    ForEach(home.scenes) { scene in
                        SceneRow(scene: scene) { home.toggleScene(scene) }
                    }
                    Text("Las escenas modifican únicamente los estados de ejemplo de esta versión.")
                        .font(.footnote).foregroundStyle(AppTheme.muted).padding(.top, 8)
                }
                .padding(22).frame(maxWidth: 900).frame(maxWidth: .infinity)
            }
            .background(AppTheme.background)
            .navigationTitle("Escenas")
        }
    }
}

struct SceneRow: View {
    let scene: HomeScene
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: scene.symbol).font(.title2).foregroundStyle(.white)
                    .frame(width: 52, height: 52).background(scene.isActive ? AppTheme.blue : AppTheme.panel2, in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 4) {
                    Text(scene.name).font(.headline).foregroundStyle(.white)
                    Text(scene.subtitle).font(.caption).foregroundStyle(AppTheme.muted)
                }
                Spacer()
                Image(systemName: scene.isActive ? "checkmark.circle.fill" : "play.circle")
                    .font(.title2).foregroundStyle(scene.isActive ? AppTheme.green : AppTheme.blue)
            }
            .padding(16).background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 20))
        }.buttonStyle(.plain)
    }
}

import SwiftUI
import AppKit

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var emphasized: Bool = true

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = emphasized ? .active : .followsWindowActiveState
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = emphasized ? .active : .followsWindowActiveState
    }
}

struct LiquidGlassBackground: View {
    var body: some View {
        VisualEffectView(material: .menu, blendingMode: .behindWindow)
            .ignoresSafeArea()
            .opacity(0.55)
    }
}

struct GlassContainer<Content: View>: View {
    let content: Content
    var highlighted: Bool = false
    init(highlighted: Bool = false, @ViewBuilder content: () -> Content) {
        self.highlighted = highlighted
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(highlighted ? Color.accentColor.opacity(0.7) : Color.white.opacity(0.08), lineWidth: highlighted ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
            .animation(.easeInOut(duration: 0.18), value: highlighted)
    }
}

struct SectionHeader: View {
    let title: String
    let systemImage: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .imageScale(.medium)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
        }
    }
}

struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .circular)
                    .fill(configuration.isPressed ? Color.accentColor.opacity(0.85) : Color.accentColor)
            )
            .foregroundStyle(.white)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}




import SwiftUI

/// The moving, glowing background. Its colors follow the song that's playing.
struct AuroraBackground: View {
    let hue: Double
    let lively: Bool
    @State private var drift = false

    var body: some View {
        ZStack {
            Color.black

            blob(Palette.accent(hue), size: 420)
                .offset(x: drift ? -120 : 90, y: drift ? -280 : -170)
            blob(Palette.second(hue), size: 380)
                .offset(x: drift ? 140 : -70, y: drift ? 110 : 250)
            blob(Palette.third(hue), size: 320)
                .offset(x: drift ? -50 : 130, y: drift ? 330 : 50)

            LinearGradient(colors: [Color.black.opacity(0.10), Color.black.opacity(0.70)],
                           startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 9).repeatForever(autoreverses: true), value: drift)
        .animation(.easeInOut(duration: 1.2), value: hue)
        .animation(.easeInOut(duration: 0.8), value: lively)
        .onAppear {
            drift = true
        }
    }

    private func blob(_ color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: 110)
            .opacity(lively ? 0.80 : 0.35)
    }
}

/// A frosted-glass rounded box used for the controls.
struct GlassBox: ViewModifier {
    var corner: CGFloat = 22

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

extension View {
    func glassBox(corner: CGFloat = 22) -> some View {
        modifier(GlassBox(corner: corner))
    }
}

import SwiftUI

/// Opening screen with the four tiles of the icon: they fly in one by one,
/// come to life (the QR code draws itself, the code fills in, the key turns,
/// the shield ticks), the name appears and everything zooms away.
/// Tap to skip.
struct SplashView: View {
    var onFinish: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var shown = [false, false, false, false]
    @State private var active = false
    @State private var pulse = false
    @State private var showTitle = false
    @State private var leaving = false
    @State private var finished = false

    private let title = Array("Pairr")

    var body: some View {
        let compact = sizeClass == .compact
        let logoSize: CGFloat = compact ? 200 : 260
        ZStack {
            IconPalette.background.ignoresSafeArea()

            // Ocean glow once the tiles come alive.
            RadialGradient(colors: [IconPalette.ocean.opacity(active ? 0.18 : 0), .clear],
                           center: .center, startRadius: 10, endRadius: active ? 520 : 80)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                PairrLogo(size: logoSize, shown: shown, active: active)
                    .scaleEffect(pulse ? 1.04 : 1)
                    .scaleEffect(leaving ? 1.45 : 1)

                VStack(spacing: 12) {
                    HStack(spacing: 1) {
                        ForEach(Array(title.enumerated()), id: \.offset) { index, letter in
                            Text(verbatim: String(letter))
                                .font(.system(size: compact ? 50 : 64, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .opacity(showTitle ? 1 : 0)
                                .offset(y: showTitle ? 0 : 20)
                                .blur(radius: showTitle ? 0 : 6)
                                .animation(.spring(response: 0.55, dampingFraction: 0.72)
                                    .delay(Double(index) * 0.06), value: showTitle)
                        }
                    }
                    Text("All your pairing codes, safe in one place")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(showTitle ? 0.6 : 0))
                        .animation(.easeOut(duration: 0.6).delay(0.25), value: showTitle)
                }
                .padding(.horizontal, 24)
            }
            .opacity(leaving ? 0 : 1)
            .blur(radius: leaving ? 14 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .sensoryFeedback(.impact(weight: .light), trigger: active)
        .task { await run() }
    }

    private func run() async {
        if reduceMotion {
            shown = [true, true, true, true]
            active = true
            showTitle = true
            try? await Task.sleep(for: .milliseconds(700))
            finish()
            return
        }
        try? await Task.sleep(for: .milliseconds(120))
        for index in 0..<4 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.66)) { shown[index] = true }
            try? await Task.sleep(for: .milliseconds(100))
        }
        try? await Task.sleep(for: .milliseconds(200))
        withAnimation(.easeInOut(duration: 0.8)) { active = true }
        try? await Task.sleep(for: .milliseconds(550))
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { pulse = true }
        showTitle = true
        try? await Task.sleep(for: .milliseconds(160))
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { pulse = false }
        try? await Task.sleep(for: .milliseconds(800))
        guard !finished else { return }
        withAnimation(.easeIn(duration: 0.4)) { leaving = true }
        try? await Task.sleep(for: .milliseconds(350))
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinish()
    }
}

#Preview {
    SplashView {}
}

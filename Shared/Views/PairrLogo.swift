import SwiftUI

/// Colours of the app icon (brand C: ocean + mint).
enum IconPalette {
    static let background = Color(red: 0x09 / 255, green: 0x18 / 255, blue: 0x28 / 255)
    static let paper = Color(red: 0xF4 / 255, green: 0xF8 / 255, blue: 0xFC / 255)
    static let ink = Color(red: 0x0A / 255, green: 0x1A / 255, blue: 0x2C / 255)
    static let darkTile = Color(red: 0x1A / 255, green: 0x2C / 255, blue: 0x42 / 255)
    static let ocean = Color(red: 0x38 / 255, green: 0xC8 / 255, blue: 0xFF / 255)
    static let keyInk = Color(red: 0x06 / 255, green: 0x28 / 255, blue: 0x3F / 255)
    static let mint = Color(red: 0x2E / 255, green: 0xD3 / 255, blue: 0xA3 / 255)

    /// Corner radius as a share of the tile size (as in the icon).
    static let cornerRatio: CGFloat = 0.247
}

// MARK: QR

struct QRTile: View {
    var size: CGFloat
    /// 0…1: how much of the code has been "drawn".
    var progress: Double

    private static let pattern = [
        "...1.1...", "....1....", "...11.1..", "1.1.1.1.1", ".1.1M.11.",
        "11..1.1.1", "...1.11.1", "....11.1.", "...1..11.",
    ]
    private static let modules: [(Int, Int, Bool)] = {
        var out: [(Int, Int, Bool)] = []
        for (y, row) in pattern.enumerated() {
            for (x, c) in row.enumerated() {
                if (x < 3 && y < 3) || (x > 5 && y < 3) || (x < 3 && y > 5) { continue }
                if c == "1" || c == "M" { out.append((x, y, c == "M")) }
            }
        }
        return out
    }()

    var body: some View {
        let u = size / 11.5
        let origin = (size - 9 * u) / 2
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: size * IconPalette.cornerRatio, style: .continuous)
                .fill(IconPalette.paper)
            ForEach(0..<3, id: \.self) { i in
                let fx = i == 1 ? 6 : 0
                let fy = i == 2 ? 6 : 0
                finder(u: u)
                    .scaleEffect(progress > 0 ? 1 : 0.4, anchor: .center)
                    .opacity(progress > 0 ? 1 : 0)
                    .offset(x: origin + CGFloat(fx) * u, y: origin + CGFloat(fy) * u)
            }
            ForEach(Array(Self.modules.enumerated()), id: \.offset) { index, m in
                let visible = progress > 0
                RoundedRectangle(cornerRadius: u * 0.32, style: .continuous)
                    .fill(m.2 ? IconPalette.ocean : IconPalette.ink)
                    .frame(width: u * 0.76, height: u * 0.76)
                    .scaleEffect(visible ? 1 : 0.2)
                    .opacity(visible ? 1 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6).delay(Double(index) * 0.012), value: progress)
                    .offset(x: origin + CGFloat(m.0) * u + u * 0.12, y: origin + CGFloat(m.1) * u + u * 0.12)
            }
        }
        .frame(width: size, height: size)
    }

    private func finder(u: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: u * 0.9, style: .continuous).fill(IconPalette.ink)
                .frame(width: 3 * u, height: 3 * u)
            RoundedRectangle(cornerRadius: u * 0.5, style: .continuous).fill(IconPalette.paper)
                .frame(width: 1.9 * u, height: 1.9 * u)
            RoundedRectangle(cornerRadius: u * 0.3, style: .continuous).fill(IconPalette.ink)
                .frame(width: 1.1 * u, height: 1.1 * u)
        }
        .frame(width: 3 * u, height: 3 * u)
    }
}

// MARK: HomeKit code sticker

struct CodeTile: View {
    var size: CGFloat
    var active: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * IconPalette.cornerRatio, style: .continuous)
                .fill(IconPalette.darkTile)
            HStack(spacing: size * 0.06) {
                Image(systemName: "house.fill")
                    .font(.system(size: size * 0.24, weight: .bold))
                    .foregroundStyle(IconPalette.ocean)
                VStack(spacing: size * 0.05) {
                    ForEach(0..<2, id: \.self) { row in
                        HStack(spacing: size * 0.05) {
                            ForEach(0..<3, id: \.self) { col in
                                let index = row * 3 + col
                                Capsule()
                                    .fill(Color.white)
                                    .frame(width: size * 0.085, height: size * 0.15)
                                    .scaleEffect(y: active ? 1 : 0.15, anchor: .bottom)
                                    .opacity(active ? 1 : 0.25)
                                    .animation(.spring(response: 0.35, dampingFraction: 0.6)
                                        .delay(Double(index) * 0.05), value: active)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: Key

struct KeyTile: View {
    var size: CGFloat
    var active: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * IconPalette.cornerRatio, style: .continuous)
                .fill(IconPalette.ocean)
            Image(systemName: "key.horizontal.fill")
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(IconPalette.keyInk)
                .rotationEffect(.degrees(active ? -40 : -130))
        }
        .frame(width: size, height: size)
    }
}

// MARK: Shield

struct ShieldTile: View {
    var size: CGFloat
    var active: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * IconPalette.cornerRatio, style: .continuous)
                .fill(IconPalette.mint)
            Image(systemName: "shield.fill")
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(.white)
            CheckMark()
                .trim(from: 0, to: active ? 1 : 0)
                .stroke(IconPalette.mint, style: StrokeStyle(lineWidth: size * 0.065, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.24, height: size * 0.18)
                .offset(y: -size * 0.01)
        }
        .frame(width: size, height: size)
    }
}

private struct CheckMark: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY + r.height * 0.05))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.38, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        return p
    }
}

// MARK: The logo: 2×2 tiles like the icon

struct PairrLogo: View {
    /// Width of the whole grid.
    var size: CGFloat
    /// Which tiles are visible (for the fly-in animation).
    var shown: [Bool] = [true, true, true, true]
    /// Tiles "on": QR drawn, code filled, key turned, shield ticked.
    var active: Bool = true

    var body: some View {
        let tile = size * 340 / 724
        let gap = size * 44 / 724
        VStack(spacing: gap) {
            HStack(spacing: gap) {
                place(QRTile(size: tile, progress: active ? 1 : 0), index: 0, dx: -1, dy: -1)
                place(CodeTile(size: tile, active: active), index: 1, dx: 1, dy: -1)
            }
            HStack(spacing: gap) {
                place(KeyTile(size: tile, active: active), index: 2, dx: -1, dy: 1)
                place(ShieldTile(size: tile, active: active), index: 3, dx: 1, dy: 1)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("Pairr")
    }

    private func place<V: View>(_ view: V, index: Int, dx: CGFloat, dy: CGFloat) -> some View {
        let visible = index < shown.count ? shown[index] : true
        return view
            .scaleEffect(visible ? 1 : 0.2)
            .rotationEffect(.degrees(visible ? 0 : Double(dx * dy) * 18))
            .offset(x: visible ? 0 : dx * size * 0.35, y: visible ? 0 : dy * size * 0.35)
            .opacity(visible ? 1 : 0)
    }
}

#Preview {
    PairrLogo(size: 260)
        .padding(60)
        .background(IconPalette.background)
}

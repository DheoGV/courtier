import SwiftUI

/// The Courtier crown: three points, the middle one a padel ball.
/// Traced from the "Mark / Courtier" component in design/padel-score.pen (artboard units, 70.6 × 39.1).
struct CrownShape: Shape {
    private static let bounds = CGRect(x: 24.674, y: 41.824, width: 70.606, height: 39.116)

    func path(in rect: CGRect) -> Path {
        let b = Self.bounds
        let scale = min(rect.width / b.width, rect.height / b.height)
        let dx = rect.midX - b.midX * scale, dy = rect.midY - b.midY * scale
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * scale + dx, y: y * scale + dy) }
        func circle(_ x: CGFloat, _ y: CGFloat, _ d: CGFloat) -> CGRect {
            CGRect(origin: p(x, y), size: CGSize(width: d * scale, height: d * scale))
        }

        var path = Path()
        // Side balls and the centre padel ball with its two seams.
        path.addEllipse(in: circle(24.674, 47.748, 6.106))
        path.addEllipse(in: circle(89.174, 47.748, 6.106))
        path.addEllipse(in: circle(53.871, 41.824, 12.211))
        path.move(to: p(55.935, 43.59))
        path.addCurve(to: p(57.885, 47.955), control1: p(57.105, 44.655), control2: p(57.885, 46.14))
        path.addCurve(to: p(55.935, 52.425), control1: p(57.885, 49.77), control2: p(57.105, 51.45))
        path.move(to: p(64.005, 43.59))
        path.addCurve(to: p(62.205, 47.955), control1: p(62.835, 44.655), control2: p(62.205, 46.14))
        path.addCurve(to: p(64.005, 52.425), control1: p(62.205, 49.77), control2: p(62.835, 51.45))
        // Outer sides.
        path.move(to: p(28.635, 53.865))
        path.addCurve(to: p(39.81, 80.94), control1: p(34.935, 62.49), control2: p(38.865, 73.335))
        path.move(to: p(91.455, 53.955))
        path.addCurve(to: p(80.22, 80.94), control1: p(85.125, 62.625), control2: p(81.21, 73.35))
        // The two arches meeting under the centre ball.
        path.move(to: p(28.635, 53.955))
        path.addCurve(to: p(46.32, 64.335), control1: p(33.75, 60.15), control2: p(40.755, 64.335))
        path.addCurve(to: p(59.31, 54.135), control1: p(52.155, 64.335), control2: p(57.27, 59.775))
        path.move(to: p(91.365, 53.955))
        path.addCurve(to: p(73.68, 64.335), control1: p(86.055, 60.15), control2: p(79.155, 64.335))
        path.addCurve(to: p(60.69, 54.135), control1: p(67.74, 64.335), control2: p(62.7, 59.775))
        // Base.
        path.move(to: p(34.32, 80.94))
        path.addLine(to: p(85.635, 80.94))
        return path
    }
}

struct CrownMark: View {
    var width: CGFloat = 26
    var lineWidth: CGFloat = 1.5
    var color: Color = .brassInk

    var body: some View {
        CrownShape()
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .padding(lineWidth / 2)
            .frame(width: width, height: width * 39.116 / 70.606 + lineWidth)
            .accessibilityHidden(true)
    }
}

/// Crown + COURTIER wordmark, shown above screen titles.
struct BrandRow: View {
    var onHero = false

    var body: some View {
        HStack(spacing: 8) {
            CrownMark(color: onHero ? .heroAccent : .brassInk)
            Text("COURTIER")
                .font(.marcellus(13))
                .tracking(4)
                .foregroundStyle(onHero ? .onRacing : .ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Courtier")
    }
}

#Preview {
    VStack(spacing: 24) {
        CrownMark(width: 200, lineWidth: 3)
        BrandRow()
    }
    .padding()
    .background(.appBackground)
}

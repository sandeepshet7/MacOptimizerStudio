import SwiftUI

// MARK: - Mini Sparkline Chart

struct Sparkline: View {
    let data: [Double]
    var tint: Color = .blue
    var height: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let maxVal = data.max() ?? 1
            let minVal = data.min() ?? 0
            let range = max(maxVal - minVal, 0.001)

            Path { path in
                guard data.count > 1 else { return }
                let stepX = geo.size.width / CGFloat(data.count - 1)

                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = geo.size.height * (1 - CGFloat((value - minVal) / range))
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(
                LinearGradient(colors: [tint.opacity(0.5), tint], startPoint: .leading, endPoint: .trailing),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            )

            // Fill area under the line
            Path { path in
                guard data.count > 1 else { return }
                let stepX = geo.size.width / CGFloat(data.count - 1)

                path.move(to: CGPoint(x: 0, y: geo.size.height))
                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = geo.size.height * (1 - CGFloat((value - minVal) / range))
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(colors: [tint.opacity(0.15), tint.opacity(0.02)], startPoint: .top, endPoint: .bottom)
            )
        }
        .frame(height: height)
    }
}

// MARK: - Proportional Progress Bar

struct ProportionalBar: View {
    let value: Double // 0..1
    var tint: Color = .orange
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.06))
                Capsule()
                    .fill(tint)
                    .frame(width: max(2, geo.size.width * min(max(value, 0), 1)))
                    .animation(.easeInOut(duration: 0.6), value: value)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Severity Badge

enum SeverityLevel {
    case healthy, moderate, critical

    var label: String {
        switch self {
        case .healthy: return "Healthy"
        case .moderate: return "Moderate"
        case .critical: return "Critical"
        }
    }

    var color: Color {
        switch self {
        case .healthy: return .green
        case .moderate: return .orange
        case .critical: return .red
        }
    }

    var icon: String {
        switch self {
        case .healthy: return "checkmark.circle.fill"
        case .moderate: return "exclamationmark.circle.fill"
        case .critical: return "xmark.circle.fill"
        }
    }
}

struct SeverityBadge: View {
    let level: SeverityLevel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: level.icon)
                .font(.caption2)
            Text(level.label)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(level.color.opacity(0.15))
        .foregroundStyle(level.color)
        .clipShape(Capsule())
    }
}

// MARK: - Staggered Animation Modifier

struct StaggeredAppear: ViewModifier {
    let index: Int
    let total: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .onAppear {
                let delay = Double(index) * 0.06
                withAnimation(.easeOut(duration: 0.35).delay(delay)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func staggeredAppear(index: Int, total: Int = 10) -> some View {
        modifier(StaggeredAppear(index: index, total: total))
    }
}

// MARK: - Section Transition

struct SectionTransition: ViewModifier {
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .onAppear {
                withAnimation(.easeOut(duration: 0.25)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func sectionTransition() -> some View {
        modifier(SectionTransition())
    }
}

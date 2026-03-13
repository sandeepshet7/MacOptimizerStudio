import SwiftUI

@MainActor
final class ToastManager: ObservableObject {
    @Published var message: String?
    @Published var isError: Bool = false

    func show(_ message: String, isError: Bool = false) {
        self.isError = isError
        self.message = message
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if self.message == message {
                self.message = nil
            }
        }
    }
}

struct ToastOverlay: ViewModifier {
    @ObservedObject var manager: ToastManager

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if let message = manager.message {
                    HStack(spacing: 8) {
                        Image(systemName: manager.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(manager.isError ? .red : .green)
                        Text(message)
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThickMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                    .padding(16)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: manager.message)
    }
}

extension View {
    func toast(_ manager: ToastManager) -> some View {
        modifier(ToastOverlay(manager: manager))
    }
}

// MARK: - Skeleton Shimmer

struct SkeletonView: View {
    @State private var shimmerPhase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.06))
                .overlay(
                    LinearGradient(
                        colors: [.clear, Color.primary.opacity(0.04), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: shimmerPhase * geo.size.width)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                shimmerPhase = 1
            }
        }
    }
}

struct SkeletonCard: View {
    var height: CGFloat = 80

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SkeletonView()
                .frame(width: 100, height: 12)
            SkeletonView()
                .frame(width: 160, height: 20)
            SkeletonView()
                .frame(width: 120, height: 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .frame(height: height)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SkeletonRow: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonView()
                .frame(width: 24, height: 24)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 6) {
                SkeletonView()
                    .frame(width: 180, height: 12)
                SkeletonView()
                    .frame(width: 100, height: 10)
            }
            Spacer()
            SkeletonView()
                .frame(width: 60, height: 14)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

import SwiftUI

struct SplashScreenView: View {
    @Binding var isActive: Bool

    @State private var logoScale: CGFloat = 0.6
    @State private var textOpacity: CGFloat = 0
    @State private var textOffset: CGFloat = 24
    @State private var subtitleOpacity: CGFloat = 0
    @State private var subtitleOffset: CGFloat = 16
    @State private var particlesOpacity: CGFloat = 0
    @State private var footerOpacity: CGFloat = 0

    private let reduceMotion = UIAccessibility.isReduceMotionEnabled

    var body: some View {
        ZStack {
            AnimatedSplashBackground()

            VStack(spacing: 12) {
                Spacer()

                Image("RulyxLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 130)

                Text("RULYX")
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .offset(y: textOffset)
                    .opacity(textOpacity)
                    .overlay(
                        ShimmerOverlay()
                            .offset(y: textOffset)
                            .opacity(textOpacity)
                    )

                Text("Bluesky moderation made easy")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .offset(y: subtitleOffset)
                    .opacity(subtitleOpacity)

                Spacer()

                Text("Free  ·  Open source  ·  No ads  ·  No tracking")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
                    .opacity(footerOpacity)
                    .padding(.bottom, 40)
            }
            .padding()

            SparkleParticles()
                .opacity(particlesOpacity)
        }
        .task {
            if reduceMotion {
                isActive = false
                return
            }
            await animate()
        }
    }

    private func animate() async {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.55).delay(0.1)) {
            logoScale = 1
        }

        try? await Task.sleep(for: .seconds(0.1))

        withAnimation(.easeOut(duration: 0.35).delay(0.15)) {
            textOffset = 0
            textOpacity = 1
        }

        withAnimation(.easeOut(duration: 0.3).delay(0.4)) {
            subtitleOffset = 0
            subtitleOpacity = 1
        }

        withAnimation(.easeIn(duration: 0.4).delay(0.55)) {
            particlesOpacity = 0.8
        }

        withAnimation(.easeOut(duration: 0.25).delay(0.65)) {
            footerOpacity = 1
        }

        try? await Task.sleep(for: .seconds(5.0))

        withAnimation(.easeOut(duration: 0.3)) {
            isActive = false
        }
    }
}

// MARK: - Animated Background

private struct AnimatedSplashBackground: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            ZStack {
                Color(red: 0.04, green: 0.10, blue: 0.28)

                let time = timeline.date.timeIntervalSince1970

                SplashOrb(
                    color: Color(red: 0.15, green: 0.45, blue: 0.95).opacity(0.45),
                    position: CGPoint(
                        x: cos(time * 0.25) * 0.35 + 0.5,
                        y: sin(time * 0.3) * 0.35 + 0.5
                    ),
                    size: 260
                )

                SplashOrb(
                    color: Color(red: 0.10, green: 0.70, blue: 0.75).opacity(0.35),
                    position: CGPoint(
                        x: cos(time * 0.35 + 2.5) * 0.35 + 0.5,
                        y: sin(time * 0.25 + 1.2) * 0.35 + 0.5
                    ),
                    size: 220
                )

                SplashOrb(
                    color: Color(red: 0.50, green: 0.20, blue: 0.85).opacity(0.25),
                    position: CGPoint(
                        x: cos(time * 0.2 + 4.8) * 0.35 + 0.5,
                        y: sin(time * 0.4 + 3.1) * 0.35 + 0.5
                    ),
                    size: 190
                )
            }
        }
        .ignoresSafeArea()
    }
}

private struct SplashOrb: View {
    let color: Color
    let position: CGPoint
    let size: CGFloat

    var body: some View {
        GeometryReader { geometry in
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .blur(radius: 70)
                .position(
                    x: position.x * geometry.size.width,
                    y: position.y * geometry.size.height
                )
        }
    }
}

// MARK: - Shimmer

private struct ShimmerOverlay: View {
    @State private var offset: CGFloat = -0.7

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.clear, .white.opacity(0.5), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.3)
            .offset(x: offset * geo.size.width * 1.5)
            .blur(radius: 8)
            .blendMode(.overlay)
        }
        .onAppear {
            withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false)) {
                offset = 0.7
            }
        }
    }
}

// MARK: - Sparkle Particles

private struct SparkleParticles: View {
    private let seeds: [Double] = {
        (0..<24).map { _ in Double.random(in: 0...100) }
    }()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSince1970

                for seed in seeds {
                    let x = (cos(time * 0.25 + seed * 0.08) + 1) * 0.5
                    let y = (sin(time * 0.18 + seed * 0.12) + 1) * 0.5
                    let dotSize = (sin(time * 1.8 + seed) + 1) * 1.5 + 1
                    let alpha = (sin(time * 0.9 + seed * 2.3) + 1) * 0.3 + 0.1

                    let point = CGPoint(
                        x: x * size.width,
                        y: y * size.height
                    )

                    let rect = CGRect(
                        x: point.x - dotSize,
                        y: point.y - dotSize,
                        width: dotSize * 2,
                        height: dotSize * 2
                    )

                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(.white.opacity(alpha))
                    )
                }
            }
        }
    }
}

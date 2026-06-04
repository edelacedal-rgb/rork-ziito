import SwiftUI

/// Compact Duolingo-style stats bar: streak flame, hearts/lives and XP/level.
/// Drop at the top of the Home tab. Tapping opens the rewards detail sheet.
struct GamificationBar: View {
    @State private var game = GamificationService.shared
    @State private var showDetail = false
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 10) {
            stat(
                icon: "flame.fill",
                value: "\(game.streak)",
                tint: game.streakActiveToday ? .zAccent : .gray,
                glow: game.streakActiveToday
            )
            stat(
                icon: "heart.fill",
                value: "\(game.hearts)",
                tint: .pink,
                glow: false
            )
            stat(
                icon: "bolt.fill",
                value: "\(game.xp)",
                tint: .yellow,
                glow: false
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.zCardBG, in: .capsule)
        .overlay(Capsule().stroke(Color.zBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        .contentShape(.capsule)
        .onTapGesture {
            Haptics.tap(.light)
            showDetail = true
        }
        .onAppear {
            game.regenerateHeartsIfNeeded()
            pulse = true
        }
        .sheet(isPresented: $showDetail) {
            RewardsDetailSheet()
        }
    }

    private func stat(icon: String, value: String, tint: Color, glow: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .shadow(color: glow ? tint.opacity(0.7) : .clear, radius: glow ? 6 : 0)
                .scaleEffect(glow && pulse ? 1.08 : 1)
                .animation(glow ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : .default, value: pulse)
            Text(value)
                .font(.subheadline.weight(.heavy).monospacedDigit())
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Detailed rewards sheet: level progress, hearts with regen timer, streak,
/// the freeze shop and a GitHub-style yearly study heatmap.
struct RewardsDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var game = GamificationService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    levelCard
                    HStack(spacing: 12) {
                        heartsCard
                        streakCard
                    }
                    shopCard
                    heatmapCard
                }
                .padding()
            }
            .background(Color.zBackground)
            .scrollContentBackground(.hidden)
            .navigationTitle("Tu progreso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Listo") { dismiss() } }
            }
            .onAppear { game.regenerateHeartsIfNeeded() }
        }
    }

    private var levelCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle().fill(Color.zAccent.opacity(0.2)).frame(width: 46, height: 46)
                    Text("\(game.level)").font(.title3.weight(.heavy)).foregroundStyle(.zAccent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nivel \(game.level)").font(.headline)
                    Text("\(game.xp) XP totales").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            ProgressView(value: game.levelProgress)
                .tint(.zAccent)
            Text("\(game.xpInLevel)/\(game.xpForLevel) XP para el nivel \(game.level + 1)")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
    }

    private var heartsCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 3) {
                ForEach(0..<GamificationService.maxHearts, id: \.self) { i in
                    Image(systemName: i < game.hearts ? "heart.fill" : "heart")
                        .font(.subheadline)
                        .foregroundStyle(i < game.hearts ? .pink : .secondary.opacity(0.4))
                }
            }
            Text("Vidas").font(.caption.weight(.semibold))
            if let next = game.nextHeartIn {
                Text("Próxima en \(Self.mmss(next))")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            } else {
                Text("¡Completas!").font(.caption2).foregroundStyle(.green)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
    }

    private var streakCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(game.streakActiveToday ? .zAccent : .gray)
            Text("\(game.streak) días").font(.headline.monospacedDigit())
            Text("Racha · récord \(game.longestStreak)")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
    }

    private var shopCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Tienda offline", systemImage: "bag.fill")
                .font(.headline)
            HStack(spacing: 12) {
                Image(systemName: "snowflake")
                    .font(.title2).foregroundStyle(.cyan)
                    .frame(width: 44, height: 44)
                    .background(.cyan.opacity(0.15), in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Congelador de racha").font(.subheadline.weight(.semibold))
                    Text("Tienes \(game.freezes) · protege un día perdido")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    game.buyFreeze()
                } label: {
                    Text("\(GamificationService.freezeCost) XP")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(game.canBuyFreeze ? Color.zAccent : Color.gray.opacity(0.4), in: .capsule)
                        .foregroundStyle(.white)
                }
                .disabled(!game.canBuyFreeze)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
    }

    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Constancia", systemImage: "square.grid.3x3.fill")
                .font(.headline)
            HeatmapGrid(game: game)
            Text("Cada cuadro verde es un día que estudiaste.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
    }

    private static func mmss(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}

/// Compact GitHub-style heatmap of the last ~17 weeks of study activity.
private struct HeatmapGrid: View {
    let game: GamificationService
    private let weeks = 17
    private let calendar = Calendar.current

    var body: some View {
        let today = calendar.startOfDay(for: Date())
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: weeks)
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(0..<(weeks * 7), id: \.self) { i in
                let offset = (weeks * 7 - 1) - i
                let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
                let active = game.studied(on: day)
                RoundedRectangle(cornerRadius: 2)
                    .fill(active ? Color.zPrimary : Color.secondary.opacity(0.12))
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }
}

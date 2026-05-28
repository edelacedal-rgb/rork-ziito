import Foundation
import SwiftUI

/// Local-first Duolingo-style gamification: hearts/lives, XP, daily streak and
/// streak freezes. All state is persisted on-device via UserDefaults (no cloud).
@Observable
@MainActor
final class GamificationService {
    static let shared = GamificationService()

    // MARK: - Tunables

    static let maxHearts = 5
    /// One heart regenerates after this interval.
    static let heartRefillInterval: TimeInterval = 30 * 60
    /// XP awarded for completing a focus cycle.
    static let xpPerFocusCycle = 20
    /// XP awarded the first study session of a day (streak bonus).
    static let xpDailyBonus = 30
    /// Cost of one streak freeze, paid in XP.
    static let freezeCost = 200

    // MARK: - Persisted state

    private(set) var hearts: Int {
        didSet { defaults.set(hearts, forKey: Keys.hearts) }
    }
    private(set) var lastHeartLoss: Date {
        didSet { defaults.set(lastHeartLoss.timeIntervalSince1970, forKey: Keys.lastHeartLoss) }
    }
    private(set) var xp: Int {
        didSet { defaults.set(xp, forKey: Keys.xp) }
    }
    private(set) var streak: Int {
        didSet { defaults.set(streak, forKey: Keys.streak) }
    }
    private(set) var longestStreak: Int {
        didSet { defaults.set(longestStreak, forKey: Keys.longestStreak) }
    }
    private(set) var freezes: Int {
        didSet { defaults.set(freezes, forKey: Keys.freezes) }
    }
    /// startOfDay timestamps of every day the user studied (for the heatmap).
    private(set) var studyDays: Set<Double> {
        didSet { defaults.set(Array(studyDays), forKey: Keys.studyDays) }
    }

    private var lastStudyDay: Date? {
        didSet {
            defaults.set(lastStudyDay?.timeIntervalSince1970 ?? 0, forKey: Keys.lastStudyDay)
        }
    }

    private let defaults = UserDefaults.standard
    private let calendar = Calendar.current

    private enum Keys {
        static let hearts = "ziito.gam.hearts"
        static let lastHeartLoss = "ziito.gam.lastHeartLoss"
        static let xp = "ziito.gam.xp"
        static let streak = "ziito.gam.streak"
        static let longestStreak = "ziito.gam.longestStreak"
        static let freezes = "ziito.gam.freezes"
        static let lastStudyDay = "ziito.gam.lastStudyDay"
        static let studyDays = "ziito.gam.studyDays"
        static let seeded = "ziito.gam.seeded"
    }

    private init() {
        let seeded = defaults.bool(forKey: Keys.seeded)
        hearts = seeded ? defaults.integer(forKey: Keys.hearts) : Self.maxHearts
        lastHeartLoss = Date(timeIntervalSince1970: defaults.double(forKey: Keys.lastHeartLoss))
        xp = defaults.integer(forKey: Keys.xp)
        streak = defaults.integer(forKey: Keys.streak)
        longestStreak = defaults.integer(forKey: Keys.longestStreak)
        freezes = defaults.integer(forKey: Keys.freezes)
        let ts = defaults.double(forKey: Keys.lastStudyDay)
        lastStudyDay = ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        studyDays = Set((defaults.array(forKey: Keys.studyDays) as? [Double]) ?? [])
        defaults.set(true, forKey: Keys.seeded)
        regenerateHeartsIfNeeded()
    }

    // MARK: - Derived

    /// XP needed to reach the next level (simple escalating curve).
    var level: Int { max(1, xp / 500 + 1) }
    var xpInLevel: Int { xp % 500 }
    var xpForLevel: Int { 500 }
    var levelProgress: Double { Double(xpInLevel) / Double(xpForLevel) }

    /// Time until the next heart regenerates (nil when full).
    var nextHeartIn: TimeInterval? {
        guard hearts < Self.maxHearts else { return nil }
        let elapsed = Date().timeIntervalSince(lastHeartLoss)
        return max(0, Self.heartRefillInterval - elapsed.truncatingRemainder(dividingBy: Self.heartRefillInterval))
    }

    var streakActiveToday: Bool {
        guard let last = lastStudyDay else { return false }
        return calendar.isDateInToday(last)
    }

    // MARK: - Hearts

    /// Recompute hearts gained passively since the last loss.
    func regenerateHeartsIfNeeded() {
        guard hearts < Self.maxHearts else { return }
        let elapsed = Date().timeIntervalSince(lastHeartLoss)
        guard elapsed > 0 else { return }
        let gained = Int(elapsed / Self.heartRefillInterval)
        if gained > 0 {
            hearts = min(Self.maxHearts, hearts + gained)
            // Advance the reference point so the next heart is timed correctly.
            lastHeartLoss = lastHeartLoss.addingTimeInterval(Double(gained) * Self.heartRefillInterval)
            if hearts >= Self.maxHearts { lastHeartLoss = Date() }
        }
    }

    /// Spend a heart (e.g. a wrong answer in a quiz). Returns the remaining count.
    @discardableResult
    func loseHeart() -> Int {
        guard hearts > 0 else { return 0 }
        if hearts == Self.maxHearts { lastHeartLoss = Date() }
        hearts -= 1
        Haptics.notify(.warning)
        return hearts
    }

    /// Fully refill hearts (reward for completing a focus Micro-Ziito).
    func refillHearts() {
        hearts = Self.maxHearts
        lastHeartLoss = Date()
        Haptics.notify(.success)
    }

    // MARK: - XP & streak

    func addXP(_ amount: Int) {
        guard amount > 0 else { return }
        xp += amount
    }

    /// Call when the user completes a study/focus session. Awards XP, refills a
    /// heart, and advances the daily streak (with freeze fallback for gaps).
    func registerStudyCompletion(cycles: Int = 1) {
        regenerateHeartsIfNeeded()
        addXP(max(1, cycles) * Self.xpPerFocusCycle)
        // Reward: completing a Micro-Ziito tops a heart back up.
        if hearts < Self.maxHearts {
            hearts += 1
            if hearts >= Self.maxHearts { lastHeartLoss = Date() }
        }
        advanceStreak()
    }

    private func advanceStreak() {
        let today = calendar.startOfDay(for: Date())
        studyDays.insert(today.timeIntervalSince1970)

        if let last = lastStudyDay {
            let lastDay = calendar.startOfDay(for: last)
            if calendar.isDate(lastDay, inSameDayAs: today) {
                return // already counted today
            }
            let dayGap = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if dayGap == 1 {
                streak += 1
            } else if dayGap > 1 {
                // Use freezes to bridge missed days, otherwise reset.
                let missed = dayGap - 1
                if freezes >= missed {
                    freezes -= missed
                    streak += 1
                } else {
                    freezes = 0
                    streak = 1
                }
            }
            addXP(Self.xpDailyBonus)
        } else {
            streak = 1
            addXP(Self.xpDailyBonus)
        }
        lastStudyDay = today
        longestStreak = max(longestStreak, streak)
    }

    // MARK: - Shop

    var canBuyFreeze: Bool { xp >= Self.freezeCost }

    @discardableResult
    func buyFreeze() -> Bool {
        guard xp >= Self.freezeCost else { return false }
        xp -= Self.freezeCost
        freezes += 1
        Haptics.notify(.success)
        return true
    }

    // MARK: - Heatmap

    /// Returns whether the user studied on a given day.
    func studied(on date: Date) -> Bool {
        studyDays.contains(calendar.startOfDay(for: date).timeIntervalSince1970)
    }
}

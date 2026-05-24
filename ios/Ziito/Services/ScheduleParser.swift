import Foundation

struct ScheduleParser {
    private static let weekdayMap: [String: Weekday] = [
        "lunes": .monday, "lun": .monday, "monday": .monday, "mon": .monday, "l": .monday,
        "martes": .tuesday, "mar": .tuesday, "tuesday": .tuesday, "tue": .tuesday, "tues": .tuesday,
        "miercoles": .wednesday, "miércoles": .wednesday, "mie": .wednesday, "mié": .wednesday,
        "wednesday": .wednesday, "wed": .wednesday, "x": .wednesday,
        "jueves": .thursday, "jue": .thursday, "thursday": .thursday, "thu": .thursday, "j": .thursday,
        "viernes": .friday, "vie": .friday, "vier": .friday, "friday": .friday, "fri": .friday, "v": .friday,
        "sabado": .saturday, "sábado": .saturday, "sab": .saturday, "sáb": .saturday,
        "saturday": .saturday, "sat": .saturday, "s": .saturday,
        "domingo": .sunday, "dom": .sunday, "sunday": .sunday, "sun": .sunday, "d": .sunday
    ]

    /// Heuristic regex-based parser used as fallback / primary offline parser.
    static func parseClasses(from text: String) -> [ScannedClass] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var results: [ScannedClass] = []
        var currentDay: Weekday?

        for line in lines {
            // Detect a day header line
            if let day = detectDay(in: line) {
                // If line *only* contains a day, set context
                let stripped = stripDay(from: line)
                if stripped.trimmingCharacters(in: .whitespaces).count < 3 {
                    currentDay = day
                    continue
                }
                // Otherwise day is inline with class
                if let item = parseClassLine(stripped, day: day) {
                    results.append(item)
                    continue
                }
            }

            if let day = currentDay,
               let item = parseClassLine(line, day: day) {
                results.append(item)
            } else {
                // Try to detect line containing day + time + name without context
                for (key, day) in weekdayMap {
                    if line.lowercased().contains(key),
                       let item = parseClassLine(line, day: day) {
                        results.append(item)
                        break
                    }
                }
            }
        }

        return dedupe(results)
    }

    private static func dedupe(_ items: [ScannedClass]) -> [ScannedClass] {
        var seen = Set<String>()
        return items.filter {
            let key = "\($0.weekday.rawValue)|\($0.startMinuteOfDay)|\($0.endMinuteOfDay)|\($0.name.lowercased())"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private static func detectDay(in line: String) -> Weekday? {
        let lower = line.lowercased()
        for (key, day) in weekdayMap where lower.contains(key) {
            return day
        }
        return nil
    }

    private static func stripDay(from line: String) -> String {
        var out = line
        for key in weekdayMap.keys {
            if let range = out.lowercased().range(of: key) {
                out.removeSubrange(range)
            }
        }
        return out
            .replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Parses lines like: "08:00 - 09:30 Matemáticas (A201)"
    private static func parseClassLine(_ line: String, day: Weekday) -> ScannedClass? {
        let timePattern = #"(\d{1,2})[:.\s](\d{2})\s*[-–a]\s*(\d{1,2})[:.\s](\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: timePattern, options: .caseInsensitive) else {
            return nil
        }
        let ns = line as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: line, range: range), match.numberOfRanges >= 5 else {
            return nil
        }
        guard
            let h1 = Int(ns.substring(with: match.range(at: 1))),
            let m1 = Int(ns.substring(with: match.range(at: 2))),
            let h2 = Int(ns.substring(with: match.range(at: 3))),
            let m2 = Int(ns.substring(with: match.range(at: 4)))
        else { return nil }

        let start = h1 * 60 + m1
        let end = h2 * 60 + m2
        guard end > start else { return nil }

        var rest = ns.replacingCharacters(in: match.range, with: "")
            .trimmingCharacters(in: .whitespaces)

        // Extract location in parentheses
        var location = ""
        if let locRegex = try? NSRegularExpression(pattern: #"\(([^)]+)\)"#) {
            let r = NSRange(rest.startIndex..., in: rest)
            if let lm = locRegex.firstMatch(in: rest, range: r), lm.numberOfRanges >= 2,
               let lr = Range(lm.range(at: 1), in: rest) {
                location = String(rest[lr]).trimmingCharacters(in: .whitespaces)
                if let full = Range(lm.range, in: rest) {
                    rest.removeSubrange(full)
                }
            }
        }

        let name = rest
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " -–·:|"))

        guard !name.isEmpty else { return nil }

        return ScannedClass(
            name: name,
            weekday: day,
            startMinuteOfDay: start,
            endMinuteOfDay: end,
            location: location
        )
    }

    /// Parse JSON returned by AI into ScannedClass items.
    static func parseAIJSON(_ json: String) -> [ScannedClass] {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = dict["classes"] as? [[String: Any]] else {
            return []
        }
        var results: [ScannedClass] = []
        for entry in arr {
            guard
                let name = (entry["name"] as? String)?.trimmingCharacters(in: .whitespaces),
                !name.isEmpty,
                let dayStr = (entry["day"] as? String)?.lowercased(),
                let day = weekdayMap[dayStr] ?? weekdayMap.first(where: { dayStr.contains($0.key) })?.value,
                let startStr = entry["start"] as? String,
                let endStr = entry["end"] as? String,
                let start = parseTime(startStr),
                let end = parseTime(endStr),
                end > start
            else { continue }

            let location = (entry["location"] as? String) ?? ""
            results.append(ScannedClass(
                name: name,
                weekday: day,
                startMinuteOfDay: start,
                endMinuteOfDay: end,
                location: location
            ))
        }
        return dedupe(results)
    }

    private static func parseTime(_ str: String) -> Int? {
        let cleaned = str.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ".", with: ":")
        let parts = cleaned.split(separator: ":")
        guard let h = Int(parts.first ?? "") else { return nil }
        let m = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
        guard h >= 0, h < 24, m >= 0, m < 60 else { return nil }
        return h * 60 + m
    }
}

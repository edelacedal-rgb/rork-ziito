import Foundation

struct ExamParser {
    private static let monthNames: [String: Int] = [
        "enero": 1, "feb": 2, "febrero": 2,
        "mar": 3, "marzo": 3, "abr": 4, "abril": 4,
        "may": 5, "mayo": 5, "jun": 6, "junio": 6,
        "jul": 7, "julio": 7, "ago": 8, "agosto": 8,
        "sept": 9, "septiembre": 9, "set": 9, "setiembre": 9,
        "oct": 10, "octubre": 10, "nov": 11, "noviembre": 11,
        "dic": 12, "diciembre": 12
    ]

    static func parseExams(from text: String) -> [ScannedExam] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var exams: [ScannedExam] = []
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())

        for (index, line) in lines.enumerated() {
            if let date = extractDate(from: line, defaultYear: currentYear) {
                let title = extractTitle(from: line, at: index, in: lines)
                let exam = ScannedExam(title: title, date: date)
                exams.append(exam)
            }
        }

        // Remove duplicates with same title and date
        var seen = Set<String>()
        return exams.filter {
            let key = "\($0.title.lowercased())|\($0.date.timeIntervalSince1970)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private static func extractDate(from line: String, defaultYear: Int) -> Date? {
        let calendar = Calendar.current

        // Pattern: "15 de mayo", "15/mayo", "15-05", "15/05/2024", "15 may"
        let patterns: [(regex: String, extractor: (NSTextCheckingResult, String) -> Date?)] = [
            // "15 de mayo" or "15 de mayo de 2024"
            (
                #"(\d{1,2})\s+de?\s+([a-záéíóúñ]+)(?:\s+de?\s+(\d{4}))?"#,
                { result, str in
                    guard let dayRange = Range(result.range(at: 1), in: str),
                          let monthRange = Range(result.range(at: 2), in: str),
                          let day = Int(str[dayRange]),
                          let month = monthNames[String(str[monthRange]).lowercased()] else { return nil }
                    let year: Int
                    if result.range(at: 3).location != NSNotFound,
                       let yearRange = Range(result.range(at: 3), in: str) {
                        year = Int(str[yearRange]) ?? defaultYear
                    } else {
                        year = defaultYear
                    }
                    return calendar.date(from: DateComponents(year: year, month: month, day: day))
                }
            ),
            // "15/mayo" or "15-mayo"
            (
                #"(\d{1,2})[/\-]([a-záéíóúñ]{3,})"#,
                { result, str in
                    guard let dayRange = Range(result.range(at: 1), in: str),
                          let monthRange = Range(result.range(at: 2), in: str),
                          let day = Int(str[dayRange]),
                          let month = monthNames[String(str[monthRange]).lowercased()] else { return nil }
                    return calendar.date(from: DateComponents(year: defaultYear, month: month, day: day))
                }
            ),
            // "15/05/2024" or "15-05-2024" or "15/05"
            (
                #"(\d{1,2})[/\-](\d{1,2})(?:[/\-](\d{4}))?"#,
                { result, str in
                    guard let dayRange = Range(result.range(at: 1), in: str),
                          let monthRange = Range(result.range(at: 2), in: str),
                          let day = Int(str[dayRange]),
                          let month = Int(str[monthRange]) else { return nil }
                    let year: Int
                    if result.range(at: 3).location != NSNotFound,
                       let yearRange = Range(result.range(at: 3), in: str) {
                        year = Int(str[yearRange]) ?? defaultYear
                    } else {
                        year = defaultYear
                    }
                    return calendar.date(from: DateComponents(year: year, month: month, day: day))
                }
            ),
            // "15 may" or "15 mayo"
            (
                #"(\d{1,2})\s+([a-záéíóúñ]{3,})"#,
                { result, str in
                    guard let dayRange = Range(result.range(at: 1), in: str),
                          let monthRange = Range(result.range(at: 2), in: str),
                          let day = Int(str[dayRange]),
                          let month = monthNames[String(str[monthRange]).lowercased()] else { return nil }
                    return calendar.date(from: DateComponents(year: defaultYear, month: month, day: day))
                }
            )
        ]

        for (regexPattern, extractor) in patterns {
            if let regex = try? NSRegularExpression(pattern: regexPattern, options: .caseInsensitive) {
                let range = NSRange(line.startIndex..., in: line)
                if let match = regex.firstMatch(in: line, options: [], range: range) {
                    if let date = extractor(match, line) {
                        return date
                    }
                }
            }
        }

        return nil
    }

    private static func extractTitle(from line: String, at index: Int, in lines: [String]) -> String {
        // Try to get title from the same line by removing date portion
        let calendar = Calendar.current
        let cleaned = removeDatePortion(from: line)
        if cleaned.count > 2 {
            return cleaned
        }

        // Look at previous line for context
        if index > 0 {
            let prev = lines[index - 1]
            if extractDate(from: prev, defaultYear: calendar.component(.year, from: Date())) == nil {
                return prev
            }
        }

        // Look at next line for context
        if index < lines.count - 1 {
            let next = lines[index + 1]
            if extractDate(from: next, defaultYear: calendar.component(.year, from: Date())) == nil {
                return next
            }
        }

        return "Evaluación"
    }

    private static func removeDatePortion(from line: String) -> String {
        var cleaned = line
        let patterns = [
            #"\d{1,2}\s+de?\s+[a-záéíóúñ]+(?:\s+de?\s+\d{4})?"#,
            #"\d{1,2}[/\-][a-záéíóúñ]{3,}"#,
            #"\d{1,2}[/\-]\d{1,2}(?:[/\-]\d{4})?"#,
            #"\d{1,2}\s+[a-záéíóúñ]{3,}"#
        ]
        for p in patterns {
            if let regex = try? NSRegularExpression(pattern: p, options: .caseInsensitive) {
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    options: [],
                    range: NSRange(cleaned.startIndex..., in: cleaned),
                    withTemplate: ""
                )
            }
        }
        cleaned = cleaned
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
        return cleaned
    }
}

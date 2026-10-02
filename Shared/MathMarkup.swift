import Foundation

/// Protect TeX before CommonMark consumes backslashes or treats underscores as emphasis.
/// Literal code, escaped dollar signs and unpaired currency symbols stay untouched.
struct MathMarkup {
    struct Expression { let token: String; let tex: String; let display: Bool }
    let markdown: String
    let expressions: [Expression]

    init(_ source: String) {
        let chars = Array(source)
        let prefix = "MATHPLACEHOLDER" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        var output = "", expressions: [Expression] = []
        var i = 0
        var fence: (Character, Int)?
        func matches(_ text: String, at index: Int) -> Bool {
            let token = Array(text)
            return index + token.count <= chars.count && Array(chars[index..<index + token.count]) == token
        }
        while i < chars.count {
            // Preserve fenced and indented code verbatim, including quoted/list fences.
            if i == 0 || chars[i - 1] == "\n" {
                let end = chars[i...].firstIndex(of: "\n") ?? chars.count
                let line = String(chars[i..<end])
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let candidate = trimmed.replacingOccurrences(of: #"^(?:>\s*)+"#, with: "", options: .regularExpression)
                if let current = fence {
                    output += line
                    let run = candidate.prefix(while: { $0 == current.0 }).count
                    if run >= current.1 && candidate.dropFirst(run).trimmingCharacters(in: .whitespaces).isEmpty { fence = nil }
                    i = end
                    if i < chars.count { output.append(chars[i]); i += 1 }
                    continue
                }
                if let first = candidate.first, first == "`" || first == "~" {
                    let run = candidate.prefix(while: { $0 == first }).count
                    if run >= 3 {
                        fence = (first, run)
                        output += line
                        i = end
                        if i < chars.count { output.append(chars[i]); i += 1 }
                        continue
                    }
                }
                if line.hasPrefix("    ") || line.hasPrefix("\t") {
                    output += line; i = end
                    if i < chars.count { output.append(chars[i]); i += 1 }
                    continue
                }
            }
            // Destinations, autolinks and image alt text are literal, not TeX containers.
            if chars[i] == "<", let end = chars[(i + 1)...].firstIndex(of: ">"),
               !chars[i...end].contains("\n") {
                output += String(chars[i...end]); i = end + 1; continue
            }
            if matches("![", at: i), let end = chars[(i + 2)...].firstIndex(of: "]") {
                output += String(chars[i..<end]); i = end; continue
            }
            if matches("](", at: i) {
                var j = i + 2, depth = 1
                while j < chars.count && depth > 0 {
                    if chars[j] == "\\" { j += min(2, chars.count - j); continue }
                    if chars[j] == "(" { depth += 1 }
                    if chars[j] == ")" { depth -= 1 }
                    j += 1
                }
                if depth == 0 { output += String(chars[i..<j]); i = j; continue }
            }
            // CommonMark backtick spans may contain newlines; match a run of exactly the same length.
            if chars[i] == "`" {
                var length = 1
                while i + length < chars.count && chars[i + length] == "`" { length += 1 }
                var j = i + length, close: Int?
                while j < chars.count {
                    if chars[j] == "`" {
                        var run = 1
                        while j + run < chars.count && chars[j + run] == "`" { run += 1 }
                        if run == length { close = j + run; break }
                        j += run
                    } else { j += 1 }
                }
                if let end = close { output += String(chars[i..<end]); i = end; continue }
            }
            let opener: String?, closer: String?, display: Bool
            if matches("$$", at: i) { opener = "$$"; closer = "$$"; display = true }
            else if matches("\\[", at: i) { opener = "\\["; closer = "\\]"; display = true }
            else if matches("\\(", at: i) { opener = "\\("; closer = "\\)"; display = false }
            else if matches("$`", at: i) { opener = "$`"; closer = "`$"; display = false }
            else if chars[i] == "$", i + 1 < chars.count, !chars[i + 1].isWhitespace {
                opener = "$"; closer = "$"; display = false
            } else { opener = nil; closer = nil; display = false }
            if let opener, let closer {
                let start = i + opener.count
                var j = start, end: Int?
                while j < chars.count {
                    if !display && chars[j] == "\n" { break }
                    if matches(closer, at: j) {
                        let after = j + closer.count
                        let validDollar = closer != "$" || (j > start && !chars[j - 1].isWhitespace && (after == chars.count || !chars[after].isNumber))
                        if validDollar { end = j; break }
                    }
                    if chars[j] == "\\" { j += min(2, chars.count - j) } else { j += 1 }
                }
                if let end, end > start {
                    let token = prefix + "N\(expressions.count)END"
                    expressions.append(Expression(token: token, tex: String(chars[start..<end]), display: display))
                    output += token; i = end + closer.count; continue
                }
            }
            // Keep escaped punctuation intact for CommonMark, and never interpret \$ as math.
            if chars[i] == "\\", i + 1 < chars.count {
                output.append(chars[i]); output.append(chars[i + 1]); i += 2
            } else { output.append(chars[i]); i += 1 }
        }
        self.markdown = output
        self.expressions = expressions
    }

    func restore(in html: String) -> String {
        var result = html
        for expression in expressions {
            let encoded = Data(expression.tex.utf8).base64EncodedString()
            let display = expression.display ? "block" : "inline"
            // Base64 keeps TeX out of both HTML attributes and executable JavaScript.
            let replacement = "<span class=\"math-expression math-\(display)\" data-tex=\"\(encoded)\" data-display=\"\(display)\">正在渲染公式…</span>"
            result = result.replacingOccurrences(of: expression.token, with: replacement)
        }
        return result
    }
}

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

enum PathCommand: Equatable {
    case move(CGPoint)
    case line(CGPoint)
    case quad(to: CGPoint, control: CGPoint)
    case cubic(to: CGPoint, control1: CGPoint, control2: CGPoint)
    case close
}

/// Parses the subset of SVG path data used by the app's icons:
/// M, L, H, V, C, S, Q, T and Z, in absolute and relative form.
enum SVGPath {
    static func parse(_ data: String) -> [PathCommand] {
        var tokens = Tokenizer(data)
        var commands: [PathCommand] = []
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastControl: CGPoint?
        var lastCommand: Character = " "
        var command: Character?

        while let token = tokens.next() {
            switch token {
            case .command(let letter):
                command = letter
                if letter == "Z" || letter == "z" {
                    commands.append(.close)
                    current = subpathStart
                    lastControl = nil
                    lastCommand = letter
                    command = nil
                }
                continue
            case .number(let value):
                tokens.pushBack(value)
            }

            guard let active = command else { break }
            let relative = active.isLowercase
            let base = relative ? current : .zero
            func point() -> CGPoint? {
                guard let x = tokens.number(), let y = tokens.number() else { return nil }
                return CGPoint(x: base.x + x, y: base.y + y)
            }

            switch active.uppercased().first {
            case "M":
                guard let p = point() else { return commands }
                commands.append(.move(p))
                current = p
                subpathStart = p
                lastControl = nil
                // Further coordinate pairs after a move are implicit line-tos.
                command = relative ? "l" : "L"
            case "L":
                guard let p = point() else { return commands }
                commands.append(.line(p))
                current = p
                lastControl = nil
            case "H":
                guard let x = tokens.number() else { return commands }
                current = CGPoint(x: relative ? current.x + x : x, y: current.y)
                commands.append(.line(current))
                lastControl = nil
            case "V":
                guard let y = tokens.number() else { return commands }
                current = CGPoint(x: current.x, y: relative ? current.y + y : y)
                commands.append(.line(current))
                lastControl = nil
            case "C":
                guard let c1 = point(), let c2 = point(), let p = point() else { return commands }
                commands.append(.cubic(to: p, control1: c1, control2: c2))
                current = p
                lastControl = c2
            case "S":
                let reflected = "CcSs".contains(lastCommand) ? reflect(lastControl, around: current) : current
                guard let c2 = point(), let p = point() else { return commands }
                commands.append(.cubic(to: p, control1: reflected, control2: c2))
                current = p
                lastControl = c2
            case "Q":
                guard let c = point(), let p = point() else { return commands }
                commands.append(.quad(to: p, control: c))
                current = p
                lastControl = c
            case "T":
                let reflected = "QqTt".contains(lastCommand) ? reflect(lastControl, around: current) : current
                guard let p = point() else { return commands }
                commands.append(.quad(to: p, control: reflected))
                current = p
                lastControl = reflected
            default:
                return commands
            }
            lastCommand = active
        }
        return commands
    }

    private static func reflect(_ control: CGPoint?, around point: CGPoint) -> CGPoint {
        guard let control else { return point }
        return CGPoint(x: 2 * point.x - control.x, y: 2 * point.y - control.y)
    }

    private enum Token {
        case command(Character)
        case number(CGFloat)
    }

    private struct Tokenizer {
        private let scalars: [Character]
        private var index = 0
        private var pending: [CGFloat] = []

        init(_ string: String) {
            scalars = Array(string)
        }

        mutating func pushBack(_ value: CGFloat) {
            pending.insert(value, at: 0)
        }

        mutating func number() -> CGFloat? {
            if !pending.isEmpty { return pending.removeFirst() }
            guard case .number(let value)? = nextRaw() else { return nil }
            return value
        }

        mutating func next() -> Token? {
            if !pending.isEmpty { return .number(pending.removeFirst()) }
            return nextRaw()
        }

        private mutating func nextRaw() -> Token? {
            while index < scalars.count, scalars[index] == " " || scalars[index] == "," || scalars[index].isNewline || scalars[index] == "\t" {
                index += 1
            }
            guard index < scalars.count else { return nil }
            let character = scalars[index]
            if character.isLetter && character != "e" && character != "E" {
                index += 1
                return .command(character)
            }
            var text = ""
            var seenDot = false
            var seenExponent = false
            while index < scalars.count {
                let c = scalars[index]
                if c.isNumber {
                    text.append(c)
                } else if (c == "-" || c == "+") && (text.isEmpty || text.last == "e" || text.last == "E") {
                    text.append(c)
                } else if c == "." && !seenDot && !seenExponent {
                    seenDot = true
                    text.append(c)
                } else if (c == "e" || c == "E") && !seenExponent && !text.isEmpty {
                    seenExponent = true
                    text.append(c)
                } else {
                    break
                }
                index += 1
            }
            guard let value = Double(text) else {
                index += 1
                return nextRaw()
            }
            return .number(CGFloat(value))
        }
    }
}

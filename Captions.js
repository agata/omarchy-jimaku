.pragma library

function leadingClosers(text) {
    var match = text.match(/^[。！？!?、，；;」』）)\]】〉》]+/)
    return match ? match[0] : ""
}

function safeCut(characters, count) {
    // Keep opening brackets with their contents, and closing marks with the text before them.
    while (count > 1 && /[「『（(\[【〈《]/.test(characters[count - 1])) count--
    while (count < characters.length && /[。！？!?、，；;」』）)\]】〉》]/.test(characters[count])) count++
    return count
}

// Punctuation comes first. The target length is soft; permit a little more
// text to reach a natural boundary before imposing an emergency hard limit.
function extract(text, limit, flush) {
    limit = Math.max(8, limit)
    var hardLimit = Math.max(limit + 12, Math.ceil(limit * 1.5))
    var remaining = text.replace(/[\r\n]+/g, " ")
    var cues = []
    while (remaining.length) {
        remaining = remaining.replace(/^\s+/, "")
        if (!remaining.length) break
        var characters = Array.from(remaining)
        var count = 0
        for (var i = 0; i < Math.min(characters.length, hardLimit); ++i) {
            var c = characters[i]
            var end = /[。！？!?]/.test(c) || (c === "." && /\s/.test(characters[i+1] || ""))
            var comma = /[、，；;]/.test(c) || (c === "," && i+1 < characters.length && !/\d/.test(characters[i+1]))
            if (end || (comma && i >= 7)) {
                count = i+1
                while (count < characters.length && /[」』”"）)]/.test(characters[count])) count++
                break
            }
        }
        if (!count && characters.length > hardLimit) {
            count = limit
            for (var j = limit-1; j >= Math.floor(limit*0.45); --j) {
                if (/[、，,；;：:\s]/.test(characters[j])) { count=j+1; break }
            }
        }
        if (!count && flush) count = Math.min(characters.length, hardLimit)
        if (!count) break
        count = safeCut(characters, count)
        var cue = characters.slice(0,count).join("").trim()
        if (cue) cues.push(cue)
        remaining = characters.slice(count).join("")
    }
    return {cues: cues, rest: remaining}
}

// Queue pressure increases progressively; isolated captions keep normal timing.
function holdTime(cue, backlog, oldestAgeMs, mode) {
    if (mode === "realtime") return 800
    var reading = mode === "readable"
        ? Math.max(2200, Math.min(6000, Array.from(cue).length * 85 + 850))
        : Math.max(1500, Math.min(5000, Array.from(cue).length * 65 + 650))
    if (backlog <= 0) return reading
    var pressure = Math.max(backlog, Math.floor(Math.max(0, oldestAgeMs || 0) / 1500))
    var factors = [1, 0.85, 0.65, 0.45, 0.35, 0.28, 0.22, 0.18, 0.15]
    return Math.round(Math.max(mode === "readable" ? 1000 : 400, reading * factors[Math.min(8, pressure)]))
}

function nextDeadline(cue, backlog, oldestAgeMs, startedAt, currentDeadline, mode) {
    // Never extend the current cue or restart its full duration when more arrive.
    return Math.min(currentDeadline, startedAt + holdTime(cue, backlog, oldestAgeMs, mode))
}

import Foundation

/// Visual habits only. Species IDs, breeding balance and saved progress are unchanged.
struct FishSwimProfile: Equatable {
    enum Family: String, CaseIterable { case fish, seaSnake, eel, jellyfish, seahorse, turtle, ray }
    var family: Family
    var speed: Double
    var sway: Double
    var depth: Double
    var tempo: Double = 1
    var restEvery: Double = 30
    var restDuration: Double = 5
    var schoolingRate: Double = 0

    // Seconds: smaller schooling fish react promptly; heavier/gliding animals coast.
    var accelerationTime: Double {
        switch family {
        case .fish: return speed >= 15 ? 0.22 : 0.35
        case .seaSnake: return 0.4
        case .eel: return 0.48
        case .seahorse: return 0.5
        case .jellyfish: return 0.65
        case .turtle, .ray: return 0.7
        }
    }
    var stoppingTime: Double { accelerationTime * 0.55 }
    var turningTime: Double {
        switch family {
        case .fish: return speed >= 15 ? 0.55 : 0.75
        case .seaSnake, .eel: return 0.95
        case .seahorse: return 1.05
        case .turtle, .ray, .jellyfish: return 1.2
        }
    }
}

extension FishSpecies {
    var swimProfile: FishSwimProfile {
        var p = FishSwimProfile(family: .fish, speed: 12, sway: 4, depth: 0.5)
        switch form {
        case "seasnake": p = .init(family: .seaSnake, speed: 13, sway: 13, depth: 0.42, tempo: 0.85, restEvery: 42, restDuration: 6)
        case "eel": p = .init(family: .eel, speed: 8, sway: 5, depth: 0.26, tempo: 0.65, restEvery: 30, restDuration: 7)
        case "jellyfish": p = .init(family: .jellyfish, speed: 3, sway: 22, depth: 0.7, tempo: 0.7, restEvery: 0)
        case "seahorse": p = .init(family: .seahorse, speed: 4, sway: 8, depth: 0.4, tempo: 0.8, restEvery: 12, restDuration: 12)
        case "turtle": p = .init(family: .turtle, speed: 7, sway: 14, depth: 0.38, tempo: 0.55, restEvery: 38, restDuration: 10)
        case "ray": p = .init(family: .ray, speed: 9, sway: 16, depth: 0.46, tempo: 0.65, restEvery: 45, restDuration: 7)
        default: break
        }
        switch id {
        case "goldfin": p.speed = 10; p.sway = 5; p.restEvery = 26
        case "greyminnow": p.speed = 17; p.sway = 3; p.depth = 0.62; p.tempo = 1.4; p.schoolingRate = 0.055
        case "copperband": p.speed = 9; p.sway = 7; p.restEvery = 24
        case "moonhorn": p.speed = 13; p.sway = 6; p.depth = 0.6
        case "neoncleaner": p.speed = 18; p.sway = 4; p.depth = 0.35; p.tempo = 1.5; p.schoolingRate = 0.025
        case "mossback": p.speed = 7; p.sway = 2; p.depth = 0.12; p.restEvery = 16; p.restDuration = 9
        case "sapphiredamsel": p.speed = 15; p.sway = 8; p.restEvery = 23
        case "banggai": p.speed = 8; p.sway = 3; p.depth = 0.56; p.restEvery = 18; p.schoolingRate = 0.025
        case "moonjelly": p.speed = 2.5; p.tempo = 0.6
        case "goldbutterfly": p.speed = 8.5; p.sway = 7; p.depth = 0.55
        case "neonstreak": p.speed = 21; p.sway = 4; p.depth = 0.58; p.tempo = 1.6; p.restDuration = 3; p.schoolingRate = 0.07
        case "blushingfire": p.speed = 16; p.sway = 9; p.depth = 0.3; p.restEvery = 18; p.restDuration = 8
        case "creampuff": p.speed = 6; p.sway = 3; p.tempo = 0.7; p.restEvery = 15; p.restDuration = 9
        case "coralseahorse": p.depth = 0.35
        case "bandedkrait": p.tempo = 1.05
        case "ambereel": p.sway = 4; p.depth = 0.22
        case "royalgoldtail": p.speed = 12.5; p.sway = 8; p.depth = 0.65; p.tempo = 0.9
        case "skywing": p.speed = 19; p.sway = 3; p.depth = 0.82; p.restEvery = 35; p.schoolingRate = 0.025
        case "emberbarb": p.speed = 18.5; p.sway = 6; p.tempo = 1.4; p.schoolingRate = 0.045
        case "volteel": p.speed = 11; p.sway = 7; p.depth = 0.4; p.tempo = 0.85
        case "crystaljelly": p.speed = 3.2; p.depth = 0.62; p.tempo = 0.8
        case "goldenmoorish": p.speed = 10.5; p.sway = 9; p.depth = 0.6; p.tempo = 0.8
        case "voidray": p.depth = 0.3
        case "auroraeel": p.speed = 9.5; p.sway = 12; p.depth = 0.55; p.tempo = 0.5
        case "goldenseahorse": p.speed = 3; p.depth = 0.45; p.restEvery = 10; p.restDuration = 16
        case "jadeturtle": p.depth = 0.34
        case "prismkoi": p.speed = 9; p.sway = 10; p.tempo = 0.7; p.restEvery = 33
        case "leviathanfry": p.speed = 12; p.sway = 17; p.tempo = 0.7; p.depth = 0.55
        case "astraljelly": p.speed = 2.8; p.depth = 0.78; p.tempo = 0.5
        default: break
        }
        return p
    }
}

/// Stable individuality without reading or advancing the save's random generator.
struct FishIndividuality: Equatable {
    let phase: Double
    let pace: Double
    let size: Double
    let lane: Double
    init(id: UUID) {
        var hash = id.uuidString.utf8.reduce(UInt32(2_166_136_261)) { ($0 ^ UInt32($1)) &* 16_777_619 }
        hash ^= hash >> 16; hash = hash &* 0x7FEB352D
        hash ^= hash >> 15; hash = hash &* 0x846CA68B
        hash ^= hash >> 16
        phase = Double(hash & 0xFFFF) / 65_536 * 2 * .pi
        pace = 0.8 + Double((hash >> 16) & 255) / 255 * 0.4
        size = 0.92 + Double((hash >> 24) & 255) / 255 * 0.16
        lane = (Double((hash >> 8) & 255) / 255 - 0.5) * 0.22
    }
}

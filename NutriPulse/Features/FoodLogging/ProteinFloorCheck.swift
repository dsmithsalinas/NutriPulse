import Foundation

// Pure check behind Talk's "This clears your floor" tile (docs/daylight-redesign.md): shown only
// when the parsed items would bring today's protein up to the goal, never speculatively.
enum ProteinFloorCheck {
    static func clearsFloor(currentProteinG: Double, addedProteinG: Double, goalG: Double?) -> Bool {
        guard let goalG, goalG > 0 else { return false }
        guard currentProteinG < goalG else { return false }   // already there — nothing to "clear"
        return currentProteinG + addedProteinG >= goalG
    }
}

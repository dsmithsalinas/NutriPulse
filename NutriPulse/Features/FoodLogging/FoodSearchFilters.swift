import Foundation

// Search tab filter chips (docs/daylight-redesign.md: "All, Protein-dense, My foods").
enum SearchFilter: String, CaseIterable, Identifiable {
    case all          = "All"
    case proteinDense = "Protein-dense"
    case myFoods      = "My foods"

    var id: String { rawValue }
}

// FatSecret's search results carry only a human-readable summary, not structured macros
// ("Per 100g - Calories: 61kcal | Fat: 3.25g | Carbs: 6.75g | Protein: 9.1g") — this pulls the
// two numbers the Search tab needs (the protein badge, the Protein-dense filter) out of that
// string without a second network round-trip per result.
enum FoodSearchMacros {
    static func parse(_ description: String) -> (calories: Double, proteinG: Double)? {
        guard let calories = number(after: "Calories:", in: description),
              let proteinG = number(after: "Protein:", in: description) else { return nil }
        return (calories, proteinG)
    }

    private static func number(after label: String, in text: String) -> Double? {
        guard let labelRange = text.range(of: label) else { return nil }
        let rest = text[labelRange.upperBound...].drop { $0 == " " }
        let digits = rest.prefix { $0.isNumber || $0 == "." }
        return Double(digits)
    }
}

// "Protein-dense" (docs/daylight-redesign.md) needs a concrete threshold — chosen here as
// ≥10g of protein per 100 kcal, roughly a chicken breast or plain Greek yogurt's ratio and
// clearly above a typical grain, snack, or dessert.
enum ProteinDensity {
    static let minGramsPer100Calories: Double = 10

    static func isProteinDense(calories: Double, proteinG: Double) -> Bool {
        guard calories > 0 else { return false }
        return (proteinG / calories) * 100 >= minGramsPer100Calories
    }
}

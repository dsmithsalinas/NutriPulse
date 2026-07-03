import SwiftUI

// Central token system — change a color here and it updates everywhere.
// Same idea as a Tailwind theme or CSS custom properties.
enum Theme {
    enum NutrientColor {
        static let calories = Color.orange
        static let protein  = Color.blue
        static let carbs    = Color.purple
        static let fiber    = Color.green
        static let fat      = Color.yellow
        static let water    = Color.cyan
    }

    enum Spacing {
        static let xs: CGFloat  =  4
        static let sm: CGFloat  =  8
        static let md: CGFloat  = 16
        static let lg: CGFloat  = 24
        static let xl: CGFloat  = 32
    }

    enum Ring {
        static let size: CGFloat      = 72
        static let lineWidth: CGFloat =  8
    }
}

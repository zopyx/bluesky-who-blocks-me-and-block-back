import SwiftUI

extension Color {
    static let skyPrimary = Color(uiColor: UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.20, green: 0.65, blue: 1.00, alpha: 1.0)
            : UIColor(red: 0.07, green: 0.53, blue: 0.98, alpha: 1.0)
    })

    static let skyAccent = Color(uiColor: UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.15, green: 0.88, blue: 0.92, alpha: 1.0)
            : UIColor(red: 0.02, green: 0.78, blue: 0.82, alpha: 1.0)
    })
}

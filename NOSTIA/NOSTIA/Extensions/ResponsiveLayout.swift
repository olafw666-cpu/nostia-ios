import UIKit
import Combine

enum Breakpoint: Equatable {
    case small, medium, large, tablet
}

final class ResponsiveLayoutManager: ObservableObject {
    static let shared = ResponsiveLayoutManager()

    @Published private(set) var screenWidth: CGFloat = UIScreen.main.bounds.width

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refresh),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    @objc private func refresh() {
        DispatchQueue.main.async {
            self.screenWidth = UIScreen.main.bounds.width
        }
    }

    var breakpoint: Breakpoint {
        switch screenWidth {
        case ..<375:    return .small
        case 375..<415: return .medium
        case 415..<768: return .large
        default:        return .tablet
        }
    }

    var isTablet: Bool { breakpoint == .tablet }

    // Content containers: 600 pt max on tablet, unconstrained on phone
    var contentMaxWidth: CGFloat { isTablet ? 600 : .infinity }

    // Modals / sheets: 540 pt max on tablet
    var sheetMaxWidth: CGFloat { isTablet ? 540 : .infinity }

    private var spacingScale: CGFloat {
        switch breakpoint {
        case .small:  return 0.85
        case .medium: return 1.0
        case .large:  return 1.1
        case .tablet: return 1.3
        }
    }

    private var fontScale: CGFloat {
        switch breakpoint {
        case .small:  return 0.9
        case .medium: return 1.0
        case .large:  return 1.05
        case .tablet: return 1.15
        }
    }

    func spacing(_ base: CGFloat) -> CGFloat { (base * spacingScale).rounded() }
    func fontSize(_ base: CGFloat) -> CGFloat { (base * fontScale).rounded() }
}

#if os(iOS)
import SwiftUI
import UIKit

extension View {

    public func renderView<T>(in frame: CGRect = UIScreen.main.bounds, render: (UIView) -> T) -> T {
        let viewController = UIHostingController(rootView: self)
        var value: T?
        UIWindow.prepare(viewController: viewController, frame: frame) {
            value = render(viewController.view)
        }
        return value!
    }
}

extension UIWindow {

    static func prepare(viewController: UIViewController, frame: CGRect, render: () -> Void) {
        let window = UIWindow(frame: frame)
        UIView.setAnimationsEnabled(false)
        // use a root view controller so that navigation bar items are shown
        let rootViewController = UIViewController()
        rootViewController.view.backgroundColor = .clear
        rootViewController.view.frame = frame
        rootViewController.preferredContentSize = frame.size
        viewController.view.frame = frame
        rootViewController.view.addSubview(viewController.view)
        rootViewController.addChild(viewController)
        viewController.didMove(toParent: rootViewController)

        window.rootViewController = rootViewController
        window.makeKeyAndVisible()

        rootViewController.beginAppearanceTransition(true, animated: false)
        rootViewController.endAppearanceTransition()

        rootViewController.view.setNeedsLayout()
        rootViewController.view.layoutIfNeeded()

        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()

        // view is ready
        render()

        // cleanup
        window.resignKey()
        window.rootViewController = nil
        UIView.setAnimationsEnabled(true)

    }
}
#endif

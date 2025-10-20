import UIKit

final class ContextMenuPresenter: NSObject, UIGestureRecognizerDelegate {

    private weak var containerView: UIView?
    private weak var tabBar: UITabBar?
    private var overlayView: UIView?
    private var menuView: UIView?
    private var stackView: UIStackView?
    private var blurView: UIVisualEffectView?
    private var currentIndex: Int?
    private var currentItems: [NativeTabBarController.ContextItem] = []
    private var selectionHandler: ((String) -> Void)?

    private let menuWidth: CGFloat = 220
    private let itemHeight: CGFloat = 52

    func present(over container: UIView,
                 tabBar: UITabBar,
                 items: [NativeTabBarController.ContextItem],
                 tabIndex: Int,
                 route: String,
                 onSelect: @escaping (String) -> Void) {
        dismiss(animated: false)

        guard !items.isEmpty else { return }

        containerView = container
        self.tabBar = tabBar
        currentItems = items
        currentIndex = tabIndex
        selectionHandler = onSelect

        let overlay = UIView(frame: container.bounds)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.12)
        overlay.alpha = 0
        container.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: container.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        overlayView = overlay

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleOverlayTap))
        tap.delegate = self
        overlay.addGestureRecognizer(tap)

        let effect = UIBlurEffect(style: .systemMaterial)
        let blur = UIVisualEffectView(effect: effect)
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = 18
        blur.layer.masksToBounds = true

        let menuContainer = UIView()
        menuContainer.translatesAutoresizingMaskIntoConstraints = false
        menuContainer.backgroundColor = .clear
        menuContainer.layer.shadowColor = UIColor.black.withAlphaComponent(0.25).cgColor
        menuContainer.layer.shadowOpacity = 0.25
        menuContainer.layer.shadowOffset = CGSize(width: 0, height: 12)
        menuContainer.layer.shadowRadius = 18
        menuContainer.alpha = 0

        menuContainer.addSubview(blur)
        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: menuContainer.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: menuContainer.trailingAnchor),
            blur.topAnchor.constraint(equalTo: menuContainer.topAnchor),
            blur.bottomAnchor.constraint(equalTo: menuContainer.bottomAnchor)
        ])

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.distribution = .fillEqually
        stack.alignment = .fill
        stack.spacing = 0
        blur.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor)
        ])
        stackView = stack

        for item in items {
            stack.addArrangedSubview(makeRow(for: item))
        }

        overlay.addSubview(menuContainer)
        let height = CGFloat(items.count) * itemHeight
        let constraints = positionConstraints(for: menuContainer,
                                              height: height,
                                              tabIndex: tabIndex)
        NSLayoutConstraint.activate(constraints)
        menuView = menuContainer
        blurView = blur

        container.layoutIfNeeded()

        let initialTransform = CGAffineTransform.identity
            .translatedBy(x: 0, y: 12)
            .scaledBy(x: 0.9, y: 0.9)
        menuContainer.transform = initialTransform

        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()

        UIViewPropertyAnimator(duration: 0.22, dampingRatio: 0.86) {
            overlay.alpha = 1
            menuContainer.alpha = 1
            menuContainer.transform = .identity
        }.startAnimation()

        generator.impactOccurred()
    }

    func dismiss(animated: Bool = true) {
        guard let overlay = overlayView,
              let menu = menuView else { return }

        let animations = {
            overlay.alpha = 0
            menu.alpha = 0
            menu.transform = CGAffineTransform.identity
                .translatedBy(x: 0, y: 10)
                .scaledBy(x: 0.95, y: 0.95)
        }

        let completion: (Bool) -> Void = { [weak self] _ in
            self?.stackView?.arrangedSubviews.forEach { $0.removeFromSuperview() }
            self?.stackView = nil
            self?.menuView?.removeFromSuperview()
            self?.menuView = nil
            self?.overlayView?.removeFromSuperview()
            self?.overlayView = nil
            self?.blurView = nil
            self?.selectionHandler = nil
            self?.currentItems = []
            self?.currentIndex = nil
        }

        if animated {
            UIViewPropertyAnimator(duration: 0.18, curve: .easeIn) {
                animations()
            }.addCompletion(completion)
        } else {
            animations()
            completion(true)
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if let menu = menuView, touch.view?.isDescendant(of: menu) == true {
            return false
        }
        return true
    }

    @objc private func handleOverlayTap() {
        dismiss()
    }

    private func makeRow(for item: NativeTabBarController.ContextItem) -> UIView {
        let row = UIControl()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: itemHeight).isActive = true

        let effect = UIVibrancyEffect(blurEffect: UIBlurEffect(style: .systemMaterial), style: .fill)
        let vibrancyView = UIVisualEffectView(effect: effect)
        vibrancyView.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(vibrancyView)
        NSLayoutConstraint.activate([
            vibrancyView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            vibrancyView.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
            vibrancyView.topAnchor.constraint(equalTo: row.topAnchor),
            vibrancyView.bottomAnchor.constraint(equalTo: row.bottomAnchor)
        ])

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center

        if let symbol = item.sfSymbol,
           let image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)) {
            let imageView = UIImageView(image: image)
            imageView.tintColor = UIColor.label
            stack.addArrangedSubview(imageView)
        }

        let labelsStack = UIStackView()
        labelsStack.axis = .vertical
        labelsStack.spacing = 2
        labelsStack.alignment = .leading

        let titleLabel = UILabel()
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = UIColor.label
        titleLabel.text = item.title

        labelsStack.addArrangedSubview(titleLabel)

        if let subtitle = item.subtitle, !subtitle.isEmpty {
            let subtitleLabel = UILabel()
            subtitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
            subtitleLabel.textColor = UIColor.secondaryLabel
            subtitleLabel.text = subtitle
            labelsStack.addArrangedSubview(subtitleLabel)
        }

        stack.addArrangedSubview(labelsStack)
        vibrancyView.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: vibrancyView.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: vibrancyView.contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: vibrancyView.contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: vibrancyView.contentView.bottomAnchor)
        ])

        row.layer.setValue(item.id, forKey: "ctxItemId")
        row.addTarget(self, action: #selector(handleRowTap(_:)), for: .touchUpInside)

        return row
    }

    private func positionConstraints(for menu: UIView,
                                     height: CGFloat,
                                     tabIndex: Int) -> [NSLayoutConstraint] {
        guard let container = containerView,
              let tabBar = tabBar,
              let items = tabBar.items,
              tabIndex >= 0, tabIndex < items.count,
              let barButton = items[tabIndex].value(forKey: "view") as? UIView else {
            return []
        }

        let targetFrame = barButton.convert(barButton.bounds, to: container)
        let preferredY = targetFrame.minY - 16
        let safeTop = container.safeAreaInsets.top + 12
        let topConstant = max(safeTop, preferredY - height)

        let minX = menuWidth / 2 + 12
        let maxX = container.bounds.width - menuWidth / 2 - 12
        let clampedMidX = min(max(targetFrame.midX, minX), maxX)

        return [
            menu.topAnchor.constraint(equalTo: container.topAnchor, constant: topConstant),
            menu.centerXAnchor.constraint(equalTo: container.leadingAnchor, constant: clampedMidX),
            menu.widthAnchor.constraint(equalToConstant: menuWidth),
            menu.heightAnchor.constraint(equalToConstant: height)
        ]
    }

    @objc private func handleRowTap(_ sender: UIControl) {
        guard let itemId = sender.layer.value(forKey: "ctxItemId") as? String else { return }
        selectionHandler?(itemId)
        dismiss()
    }
}

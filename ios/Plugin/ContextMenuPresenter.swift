import UIKit

final class ContextMenuPresenter: NSObject, UIGestureRecognizerDelegate {

    private final class MenuRowControl: UIControl {
        private let highlightView = UIView()
        private var cachedHighlightColor: UIColor = UIColor.white.withAlphaComponent(0.04)

        override init(frame: CGRect) {
            super.init(frame: frame)
            translatesAutoresizingMaskIntoConstraints = false
            layer.cornerRadius = 16
            layer.masksToBounds = false
            isAccessibilityElement = true
            accessibilityTraits = .button

            highlightView.translatesAutoresizingMaskIntoConstraints = false
            highlightView.layer.cornerRadius = 13
            if #available(iOS 13.0, *) {
                highlightView.layer.cornerCurve = .continuous
            }
            highlightView.alpha = 0
            highlightView.isUserInteractionEnabled = false
            addSubview(highlightView)
            NSLayoutConstraint.activate([
                highlightView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
                highlightView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
                highlightView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
                highlightView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func configureHighlight(color: UIColor?, style: UIUserInterfaceStyle) {
            let base: UIColor
            switch style {
            case .dark:
                base = UIColor.white.withAlphaComponent(0.04)
            default:
                base = UIColor.black.withAlphaComponent(0.018)
            }
            cachedHighlightColor = (color?.withAlphaComponent(style == .dark ? 0.06 : 0.03)) ?? base
            highlightView.backgroundColor = cachedHighlightColor
        }

        override var isHighlighted: Bool {
            didSet {
                let targetAlpha: CGFloat = isHighlighted ? 1 : 0
                UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
                    self.highlightView.alpha = targetAlpha
                }
            }
        }
    }

    private struct RowComponents {
        let control: MenuRowControl
        let titleLabel: UILabel
        let subtitleLabel: UILabel?
        let iconView: UIImageView?
    }

    private weak var containerView: UIView?
    private weak var tabBar: UITabBar?
    private var overlayView: UIView?
    private var menuView: UIView?
    private var stackView: UIStackView?
    private var blurView: UIVisualEffectView?
    private var borderLayer: CALayer?
    private var innerBorderLayer: CALayer?
    private var currentIndex: Int?
    private var currentItems: [NativeTabBarController.ContextItem] = []
    private var selectionHandler: ((String) -> Void)?
    private var rowComponents: [RowComponents] = []

    private var currentStyle: UIUserInterfaceStyle = .unspecified
    private var titleColor: UIColor = .label
    private var subtitleColor: UIColor = .secondaryLabel
    private var backgroundTint: UIColor?
    private let menuWidth: CGFloat = 220
    private let itemHeight: CGFloat = 52

    func present(over container: UIView,
                 tabBar: UITabBar,
                 items: [NativeTabBarController.ContextItem],
                 tabIndex: Int,
                 _ route: String,
                 style: UIUserInterfaceStyle,
                 titleColor: UIColor,
                 subtitleColor: UIColor,
                 highlightColor: UIColor?,
                 backgroundColor: UIColor?,
                 onSelect: @escaping (String) -> Void) {
        dismiss(animated: false)

        guard !items.isEmpty else { return }

        containerView = container
        self.tabBar = tabBar
        currentItems = items
        currentIndex = tabIndex
        selectionHandler = onSelect

        currentStyle = style
        self.titleColor = titleColor
        self.subtitleColor = subtitleColor

        let overlay = UIView(frame: container.bounds)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = style == .dark ? UIColor.black.withAlphaComponent(0.03) : UIColor.black.withAlphaComponent(0.015)
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

        let blurEffect: UIBlurEffect
        if #available(iOS 15.0, *) {
            blurEffect = UIBlurEffect(style: style == .dark ? .systemChromeMaterialDark : .systemChromeMaterialLight)
        } else {
            blurEffect = UIBlurEffect(style: style == .dark ? .systemMaterialDark : .systemMaterial)
        }
        let blur = UIVisualEffectView(effect: blurEffect)
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = 18
        blur.layer.masksToBounds = true
        blur.layer.cornerCurve = .continuous
        blur.contentView.layer.cornerRadius = 18
        blur.contentView.layer.cornerCurve = .continuous
        blur.contentView.clipsToBounds = true
        backgroundTint = backgroundColor
        blur.contentView.backgroundColor = resolvedBackgroundColor(for: style)

        let menuContainer = UIView()
        menuContainer.translatesAutoresizingMaskIntoConstraints = false
        menuContainer.backgroundColor = .clear
        menuContainer.layer.shadowColor = UIColor.black.withAlphaComponent(style == .dark ? 0.07 : 0.045).cgColor
        menuContainer.layer.shadowOpacity = 1
        menuContainer.layer.shadowOffset = CGSize(width: 0, height: 18)
        menuContainer.layer.shadowRadius = 32
        menuContainer.layer.cornerRadius = 18
        menuContainer.layer.cornerCurve = .continuous
        menuContainer.alpha = 0
        menuContainer.clipsToBounds = false

        menuContainer.addSubview(blur)
        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: menuContainer.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: menuContainer.trailingAnchor),
            blur.topAnchor.constraint(equalTo: menuContainer.topAnchor),
            blur.bottomAnchor.constraint(equalTo: menuContainer.bottomAnchor)
        ])

        let border = CALayer()
        border.cornerRadius = 18
        border.borderWidth = 1.0
        border.borderColor = UIColor.white.withAlphaComponent(style == .dark ? 0.04 : 0.055).cgColor
        blur.layer.addSublayer(border)
        borderLayer = border

        let inner = CALayer()
        inner.cornerRadius = 17.5
        inner.borderWidth = 0.5
        inner.borderColor = UIColor.white.withAlphaComponent(style == .dark ? 0.02 : 0.035).cgColor
        blur.contentView.layer.addSublayer(inner)
        innerBorderLayer = inner

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

        rowComponents.removeAll(keepingCapacity: true)
        for item in items {
            let row = makeRow(for: item,
                              style: style,
                              titleColor: titleColor,
                              subtitleColor: subtitleColor,
                              highlightColor: highlightColor)
            stack.addArrangedSubview(row.control)
            rowComponents.append(row)
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
        updateGlassLayers()

        let initialTransform = CGAffineTransform(translationX: 0, y: 26)
            .scaledBy(x: 0.82, y: 0.82)
        menuContainer.transform = initialTransform
        menuContainer.layer.shadowPath = UIBezierPath(roundedRect: menuContainer.bounds, cornerRadius: 18).cgPath

        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()

        overlay.alpha = 0
        menuContainer.alpha = 0

        UIView.animateKeyframes(withDuration: 0.36, delay: 0, options: [.calculationModeCubic], animations: {
            UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.45) {
                overlay.alpha = 1
                menuContainer.alpha = 1
                menuContainer.transform = CGAffineTransform(translationX: 0, y: 4).scaledBy(x: 1.08, y: 1.08)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.45, relativeDuration: 0.3) {
                menuContainer.transform = CGAffineTransform(translationX: 0, y: -2).scaledBy(x: 0.97, y: 0.97)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.75, relativeDuration: 0.25) {
                menuContainer.transform = .identity
            }
        }, completion: nil)

        generator.impactOccurred()
    }

    func dismiss(animated: Bool = true) {
        guard let overlay = overlayView,
              let menu = menuView else { return }

        let animations = {
            overlay.alpha = 0
            menu.alpha = 0
            menu.transform = CGAffineTransform.identity
                .translatedBy(x: 0, y: 12)
                .scaledBy(x: 0.92, y: 0.92)
        }

        let cleanup = { [weak self] in
            self?.stackView?.arrangedSubviews.forEach { $0.removeFromSuperview() }
            self?.stackView = nil
            self?.menuView?.removeFromSuperview()
            self?.menuView = nil
            self?.overlayView?.removeFromSuperview()
            self?.overlayView = nil
            self?.blurView = nil
            self?.borderLayer?.removeFromSuperlayer()
            self?.borderLayer = nil
            self?.innerBorderLayer?.removeFromSuperlayer()
            self?.innerBorderLayer = nil
            self?.selectionHandler = nil
            self?.currentItems = []
            self?.currentIndex = nil
            self?.rowComponents = []
            self?.backgroundTint = nil
        }

        if animated {
            UIView.animateKeyframes(withDuration: 0.22, delay: 0, options: [.calculationModeCubic], animations: {
                UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.45) {
                    menu.transform = CGAffineTransform(translationX: 0, y: 6).scaledBy(x: 0.94, y: 0.94)
                    menu.alpha = 0.7
                }
                UIView.addKeyframe(withRelativeStartTime: 0.45, relativeDuration: 0.55) {
                    animations()
                }
            }, completion: { _ in
                cleanup()
            })
        } else {
            animations()
            cleanup()
        }
    }

    func updateColors(style: UIUserInterfaceStyle, titleColor: UIColor, subtitleColor: UIColor, highlightColor: UIColor?, backgroundColor: UIColor?) {
        currentStyle = style
        self.titleColor = titleColor
        self.subtitleColor = subtitleColor
        backgroundTint = backgroundColor

        rowComponents.forEach { row in
            row.control.configureHighlight(color: highlightColor, style: style)
            row.titleLabel.textColor = titleColor
            row.subtitleLabel?.textColor = subtitleColor
            row.iconView?.tintColor = titleColor
        }

        if let border = borderLayer {
            border.borderColor = UIColor.white.withAlphaComponent(style == .dark ? 0.04 : 0.055).cgColor
        }

        if let inner = innerBorderLayer {
            inner.borderColor = UIColor.white.withAlphaComponent(style == .dark ? 0.02 : 0.035).cgColor
        }

        overlayView?.backgroundColor = style == .dark ? UIColor.black.withAlphaComponent(0.03) : UIColor.black.withAlphaComponent(0.015)
        menuView?.layer.shadowColor = UIColor.black.withAlphaComponent(style == .dark ? 0.07 : 0.045).cgColor
        blurView?.contentView.backgroundColor = resolvedBackgroundColor(for: style)
        blurView?.layer.cornerRadius = 18
        blurView?.layer.cornerCurve = .continuous
        blurView?.contentView.layer.cornerRadius = 18
        blurView?.contentView.layer.cornerCurve = .continuous

        updateGlassLayers()
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

    private func makeRow(for item: NativeTabBarController.ContextItem,
                         style: UIUserInterfaceStyle,
                         titleColor: UIColor,
                         subtitleColor: UIColor,
                         highlightColor: UIColor?) -> RowComponents {
        let row = MenuRowControl()
        row.heightAnchor.constraint(equalToConstant: itemHeight).isActive = true
        row.configureHighlight(color: highlightColor, style: style)
        row.accessibilityLabel = item.title
        if let subtitle = item.subtitle, !subtitle.isEmpty {
            row.accessibilityValue = subtitle
        } else {
            row.accessibilityValue = nil
        }

        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.isUserInteractionEnabled = false
        row.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            contentView.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
            contentView.topAnchor.constraint(equalTo: row.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: row.bottomAnchor)
        ])

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.isUserInteractionEnabled = false

        let iconContainer = UIView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.widthAnchor.constraint(equalToConstant: 28).isActive = true
        iconContainer.heightAnchor.constraint(equalToConstant: 28).isActive = true
        iconContainer.isUserInteractionEnabled = false

        var iconView: UIImageView?
        if let symbol = item.sfSymbol,
           let image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)) {
            let imageView = UIImageView(image: image)
            imageView.tintColor = titleColor
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            iconContainer.addSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor)
            ])
            iconView = imageView
        }
        stack.addArrangedSubview(iconContainer)

        let labelsStack = UIStackView()
        labelsStack.axis = .vertical
        labelsStack.spacing = 2
        labelsStack.alignment = .leading
        labelsStack.isUserInteractionEnabled = false

        let titleLabel = UILabel()
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = titleColor
        titleLabel.text = item.title
        labelsStack.addArrangedSubview(titleLabel)

        var subtitleLabel: UILabel?
        if let subtitle = item.subtitle, !subtitle.isEmpty {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
            label.textColor = subtitleColor
            label.text = subtitle
            labelsStack.addArrangedSubview(label)
            subtitleLabel = label
        }

        stack.addArrangedSubview(labelsStack)
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        row.layer.setValue(item.id, forKey: "ctxItemId")
        row.addTarget(self, action: #selector(handleRowTap(_:)), for: .touchUpInside)

        return RowComponents(control: row, titleLabel: titleLabel, subtitleLabel: subtitleLabel, iconView: iconView)
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
        let safeBottom = container.safeAreaInsets.bottom + 12
        let maxTop = container.bounds.height - safeBottom - height
        let topConstant = min(max(safeTop, preferredY - height), maxTop)

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

    private func resolvedBackgroundColor(for style: UIUserInterfaceStyle) -> UIColor {
        if let tint = backgroundTint {
            let alpha: CGFloat = style == .dark ? 0.025 : 0.02
            return tint.withAlphaComponent(alpha)
        }
        return style == .dark ? UIColor.white.withAlphaComponent(0.004) : UIColor.white.withAlphaComponent(0.0125)
    }

    private func updateGlassLayers() {
        guard let blur = blurView,
              let menu = menuView else { return }
        borderLayer?.frame = blur.bounds
        if let inner = innerBorderLayer {
            let insetBounds = blur.contentView.bounds.insetBy(dx: 0.25, dy: 0.25)
            inner.frame = insetBounds
            inner.cornerRadius = max(0, blur.contentView.layer.cornerRadius - 0.5)
        }
        menu.layer.shadowPath = UIBezierPath(roundedRect: menu.bounds, cornerRadius: menu.layer.cornerRadius).cgPath
    }
}

// NativeTabBarController.swift (no icon animations)
import UIKit

struct HexUtil {
    static func color(_ hex: String?) -> UIColor? {
        guard var s = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0; Scanner(string: s).scanHexInt64(&v)
        if s.count == 6 {
            let r = CGFloat((v & 0xFF0000) >> 16)/255.0
            let g = CGFloat((v & 0x00FF00) >> 8)/255.0
            let b = CGFloat(v & 0x0000FF)/255.0
            return UIColor(red: r, green: g, blue: b, alpha: 1)
        } else if s.count == 8 {
            let a = CGFloat((v & 0xFF000000) >> 24)/255.0
            let r = CGFloat((v & 0x00FF0000) >> 16)/255.0
            let g = CGFloat((v & 0x0000FF00) >> 8)/255.0
            let b = CGFloat(v & 0x000000FF)/255.0
            return UIColor(red: r, green: g, blue: b, alpha: a)
        }
        return nil
    }
    static func tintedSymbol(_ name: String, color: UIColor?, point: CGFloat = 18, weight: UIImage.SymbolWeight = .regular) -> UIImage? {
        let cfg = UIImage.SymbolConfiguration(pointSize: point, weight: weight)
        guard let base = UIImage(systemName: name, withConfiguration: cfg) else { return nil }
        guard let color = color else { return base }
        return base.withTintColor(color, renderingMode: .alwaysOriginal)
    }
}

final class NativeTabBarController: UIViewController, UITabBarDelegate, UIContextMenuInteractionDelegate {

    struct IconColors { var normal: String?; var selected: String?; var disabled: String? }
    struct TitlePalette {
        var lightNormal: String?; var lightSelected: String?; var lightDisabled: String?
        var darkNormal: String?;  var darkSelected: String?;  var darkDisabled: String?
    }
    struct ContextItem { let id: String; let title: String; let subtitle: String?; let sfSymbol: String? }
    struct TabItem { let title: String; let sfSymbol: String; let route: String; let badge: String?; var iconColors: IconColors?; var ctxItems: [ContextItem]?; var titlePalette: TitlePalette? }

    var onSelect: ((Int, String, Bool) -> Void)?
    var onLongPress: ((Int, String) -> Void)?
    var onContextItem: ((Int, String) -> Void)?

    let tabBar = UITabBar(frame: .zero)

    private var items: [TabItem] = []
    private var selectedIndex: Int = 0

    private var globalColors = IconColors(normal: "#9AA0A6", selected: "#0A84FF", disabled: "#C7C7CC")
    private var perTabColors: [Int: IconColors] = [:]

    private var globalTitles = TitlePalette(lightNormal: nil, lightSelected: nil, lightDisabled: nil, darkNormal: nil, darkSelected: nil, darkDisabled: nil)
    private var perTabTitles: [Int: TitlePalette] = [:]

    private var defaultCtx: [ContextItem] = []
    private var perTabCtx: [Int: [ContextItem]] = [:]
    private var longPressEnabled = true
    private var forcedInterfaceStyle: UIUserInterfaceStyle = .unspecified
    private weak var trackedWindow: UIWindow?

    private func tabButtonViews() -> [UIView] {
        let buttonClass = NSClassFromString("UITabBarButton")
        let buttons: [UIView] = tabBar.subviews.compactMap { view in
            guard let buttonClass, view.isKind(of: buttonClass) else { return nil }
            return view
        }
        return buttons.sorted(by: { $0.frame.minX < $1.frame.minX })
    }

    private func indexForLocation(_ location: CGPoint) -> Int? {
        guard let items = tabBar.items, !items.isEmpty else { return nil }
        tabBar.layoutIfNeeded()
        let buttons = tabButtonViews()
        if buttons.count == items.count {
            for (idx, button) in buttons.enumerated() {
                let frame = button.convert(button.bounds, to: tabBar)
                if frame.contains(location) {
                    return idx
                }
            }
            if let nearest = buttons.enumerated().min(by: { lhs, rhs in
                let lhsCenter = lhs.element.convert(lhs.element.bounds, to: tabBar).midX
                let rhsCenter = rhs.element.convert(rhs.element.bounds, to: tabBar).midX
                return abs(lhsCenter - location.x) < abs(rhsCenter - location.x)
            })?.offset {
                return nearest
            }
        }
        let width = max(tabBar.bounds.width, 1)
        let raw = Int((location.x / width) * CGFloat(items.count))
        return max(0, min(items.count - 1, raw))
    }

    private func applyInterfaceStyle() {
        overrideUserInterfaceStyle = forcedInterfaceStyle
        view.overrideUserInterfaceStyle = forcedInterfaceStyle
        tabBar.overrideUserInterfaceStyle = forcedInterfaceStyle
        if let window = view.window ?? trackedWindow {
            window.overrideUserInterfaceStyle = forcedInterfaceStyle
            trackedWindow = window
        }
    }

    private func applyAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor.clear
        appearance.shadowImage = UIImage()
        appearance.shadowColor = .clear
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        applyInterfaceStyle()
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        tabBar.delegate = self
        tabBar.itemPositioning = .automatic
        tabBar.itemSpacing = 8
        tabBar.itemWidth = 0
        tabBar.isUserInteractionEnabled = true
        applyAppearance()
        view.addSubview(tabBar)

        NSLayoutConstraint.activate([
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let ctx = UIContextMenuInteraction(delegate: self)
        tabBar.addInteraction(ctx)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyInterfaceStyle()
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        applyTitleColors()
    }

    func configure(tabs: [TabItem], selected: Int) {
        self.items = tabs
        self.selectedIndex = max(0, min(selected, tabs.count - 1))
        perTabColors.removeAll(); perTabCtx.removeAll(); perTabTitles.removeAll()
        for (i, t) in tabs.enumerated() {
            if let c = t.iconColors { perTabColors[i] = c }
            if let m = t.ctxItems { perTabCtx[i] = m }
            if let tp = t.titlePalette { perTabTitles[i] = tp }
        }
        rebuildItems()
        applyTitleColors()
    }

    private func rebuildItems() {
        let tbarItems: [UITabBarItem] = items.enumerated().map { (idx, t) in
            let normal = HexUtil.color(perTabColors[idx]?.normal ?? globalColors.normal) ?? UIColor.secondaryLabel
            let select = HexUtil.color(perTabColors[idx]?.selected ?? globalColors.selected) ?? UIColor.systemBlue
            let img = HexUtil.tintedSymbol(t.sfSymbol, color: normal)
            let sel = HexUtil.tintedSymbol(t.sfSymbol, color: select)
            let it = UITabBarItem(title: t.title, image: img, selectedImage: sel)
            it.tag = idx
            if let b = t.badge, !b.isEmpty { it.badgeValue = b }
            return it
        }
        tabBar.items = tbarItems
        if selectedIndex >= 0 && selectedIndex < tbarItems.count {
            tabBar.selectedItem = tbarItems[selectedIndex]
        }
    }

    private func applyTitleColors() {
        guard let items = tabBar.items else { return }
        let effectiveStyle: UIUserInterfaceStyle = forcedInterfaceStyle == .unspecified ? traitCollection.userInterfaceStyle : forcedInterfaceStyle
        let isDark = (effectiveStyle == .dark)

        func colorString(for palette: TitlePalette, state: UIControl.State) -> String? {
            if isDark {
                if state.contains(.disabled) { return palette.darkDisabled }
                if state.contains(.selected) { return palette.darkSelected }
                return palette.darkNormal
            } else {
                if state.contains(.disabled) { return palette.lightDisabled }
                if state.contains(.selected) { return palette.lightSelected }
                return palette.lightNormal
            }
        }

        func attributes(for palette: TitlePalette, state: UIControl.State) -> [NSAttributedString.Key: Any] {
            var attrs: [NSAttributedString.Key: Any] = [:]
            if let color = HexUtil.color(colorString(for: palette, state: state)) {
                attrs[.foregroundColor] = color
            }
            return attrs
        }

        let globalNormalAttr = attributes(for: globalTitles, state: .normal)
        let globalSelectedAttr = attributes(for: globalTitles, state: .selected)
        let globalDisabledAttr = attributes(for: globalTitles, state: .disabled)
        let appearance = tabBar.standardAppearance
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = globalNormalAttr
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = globalSelectedAttr
        appearance.stackedLayoutAppearance.disabled.titleTextAttributes = globalDisabledAttr
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = globalNormalAttr
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = globalSelectedAttr
        appearance.inlineLayoutAppearance.disabled.titleTextAttributes = globalDisabledAttr
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = globalNormalAttr
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = globalSelectedAttr
        appearance.compactInlineLayoutAppearance.disabled.titleTextAttributes = globalDisabledAttr
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }

        for (i, it) in items.enumerated() {
            let palette = perTabTitles[i] ?? globalTitles
            let normalAttr = attributes(for: palette, state: .normal)
            let selectedAttr = attributes(for: palette, state: .selected)
            let disabledAttr = attributes(for: palette, state: .disabled)
            it.setTitleTextAttributes(normalAttr, for: .normal)
            it.setTitleTextAttributes(selectedAttr, for: .selected)
            it.setTitleTextAttributes(disabledAttr, for: .disabled)
        }
    }

    func setGlobalColors(_ c: IconColors) { globalColors = c; rebuildItems() }
    func setTabColors(index: Int, _ c: IconColors) { perTabColors[index] = c; rebuildItems() }

    func setGlobalTitlePalette(_ p: TitlePalette) { globalTitles = p; applyTitleColors() }
    func setTabTitlePalette(index: Int, _ p: TitlePalette) { perTabTitles[index] = p; applyTitleColors() }

    func setLongPress(enabled: Bool) { longPressEnabled = enabled }
    func setContextMenu(index: Int, items: [ContextItem]) { perTabCtx[index] = items }
    func setDefaultContextMenu(items: [ContextItem]) { defaultCtx = items }

    func setBadge(index: Int, value: String?) {
        guard index >= 0, index < (tabBar.items?.count ?? 0) else { return }
        tabBar.items?[index].badgeValue = (value?.isEmpty == false) ? value : nil
    }

    func setInterfaceStyle(_ style: UIUserInterfaceStyle) {
        forcedInterfaceStyle = style
        applyInterfaceStyle()
        applyTitleColors()
        rebuildItems()
    }

    @discardableResult
    func select(index: Int) -> Bool {
        guard let items = tabBar.items, index >= 0, index < items.count else { return false }
        tabBar.selectedItem = items[index]
        let reselection = (index == selectedIndex)
        selectedIndex = index
        onSelect?(index, self.items[index].route, reselection)
        return true
    }

    // MARK: - UIContextMenuInteractionDelegate
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        guard longPressEnabled, let items = tabBar.items, items.count > 0 else { return nil }
        guard let idx = indexForLocation(location) else { return nil }

        onLongPress?(idx, self.items[idx].route)

        let menuItems = perTabCtx[idx] ?? defaultCtx
        guard !menuItems.isEmpty else { return nil }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self = self else { return nil }
            let actions = menuItems.map { mi -> UIAction in
                let img = mi.sfSymbol.flatMap { UIImage(systemName: $0) }
                if #available(iOS 17.0, *) {
                    return UIAction(title: mi.title, subtitle: mi.subtitle, image: img) { _ in
                        self.onContextItem?(idx, mi.id)
                    }
                } else {
                    return UIAction(title: mi.title, image: img) { _ in
                        self.onContextItem?(idx, mi.id)
                    }
                }
            }
            return UIMenu(title: "", children: actions)
        }
    }

    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        let idx = item.tag
        let route = items[idx].route
        let reselect = (idx == selectedIndex)
        selectedIndex = idx
        onSelect?(idx, route, reselect)
    }
}

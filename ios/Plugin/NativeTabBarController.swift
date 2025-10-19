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
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        tabBar.delegate = self
        tabBar.itemPositioning = .automatic
        tabBar.itemSpacing = 8
        tabBar.itemWidth = 0
        tabBar.tintColor = UIColor.systemBlue
        tabBar.unselectedItemTintColor = UIColor.secondaryLabel
        tabBar.isUserInteractionEnabled = true
        applyAppearance()
        view.addSubview(tabBar)

        NSLayoutConstraint.activate([
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        let ctx = UIContextMenuInteraction(delegate: self)
        tabBar.addInteraction(ctx)
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
        let isDark = traitCollection.userInterfaceStyle == .dark
        for (i, it) in items.enumerated() {
            let palette = perTabTitles[i] ?? globalTitles
            let n = HexUtil.color(isDark ? palette.darkNormal : palette.lightNormal)
            let s = HexUtil.color(isDark ? palette.darkSelected : palette.lightSelected)
            var normalAttr: [NSAttributedString.Key: Any] = [:]
            var selectedAttr: [NSAttributedString.Key: Any] = [:]
            if let n = n { normalAttr[.foregroundColor] = n }
            if let s = s { selectedAttr[.foregroundColor] = s }
            it.setTitleTextAttributes(normalAttr, for: .normal)
            it.setTitleTextAttributes(selectedAttr, for: .selected)
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
        let width = tabBar.bounds.width / CGFloat(items.count)
        var idx = Int(location.x / width)
        idx = max(0, min(idx, items.count - 1))

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

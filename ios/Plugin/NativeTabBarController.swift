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

final class NativeTabBarController: UIViewController, UITabBarDelegate, UIGestureRecognizerDelegate {

    struct IconColors { var normal: String?; var selected: String?; var disabled: String? }
    struct TitlePalette {
        var lightNormal: String?; var lightSelected: String?; var lightDisabled: String?
        var darkNormal: String?;  var darkSelected: String?;  var darkDisabled: String?
    }
    struct ContextItem { let id: String; let title: String; let subtitle: String?; let sfSymbol: String? }
    struct TabItem { let title: String; let sfSymbol: String; let route: String; let badge: String?; var iconColors: IconColors?; var ctxItems: [ContextItem]?; var titlePalette: TitlePalette? }
    struct MenuColorSet { var light: String?; var dark: String? }
    struct Metrics: Equatable {
        let containerFrame: CGRect
        let tabBarFrame: CGRect
        let containerSafeAreaInsets: UIEdgeInsets
        let tabBarSafeAreaInsets: UIEdgeInsets
    }

    var onSelect: ((Int, String, Bool) -> Void)?
    var onLongPress: ((Int, String) -> Void)?
    var onContextItem: ((Int, String) -> Void)?
    var onMetricsChanged: ((Metrics) -> Void)?
    var selectedTabIndex: Int { selectedIndex }

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
    private lazy var menuPresenter = ContextMenuPresenter()
    private var buttonLongPressRecognizers: [UILongPressGestureRecognizer] = []
    private var menuTitleColors = MenuColorSet(light: nil, dark: nil)
    private var menuSubtitleColors = MenuColorSet(light: nil, dark: nil)
    private var menuBackgroundTint = MenuColorSet(light: nil, dark: nil)
    private var tabBarLocked = false
    private var refreshRetryWorkItem: DispatchWorkItem?
    private var suppressSelectionFromLongPress = false
    private var cachedItemEnabledStates: [Int: Bool] = [:]

    private func applyInterfaceStyle() {
        overrideUserInterfaceStyle = forcedInterfaceStyle
        view.overrideUserInterfaceStyle = forcedInterfaceStyle
        tabBar.overrideUserInterfaceStyle = forcedInterfaceStyle
        if let window = view.window ?? trackedWindow {
            window.overrideUserInterfaceStyle = forcedInterfaceStyle
            trackedWindow = window
        }
        refreshMenuPresenterTheme()
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

    private func updateLongPressRecognizerStates() {
        let enabled = longPressEnabled && !tabBarLocked
        buttonLongPressRecognizers.forEach { $0.isEnabled = enabled }
    }

    private func scheduleLongPressRefreshRetry() {
        refreshRetryWorkItem?.cancel()
        guard longPressEnabled, !tabBarLocked else { return }
        let workItem = DispatchWorkItem { [weak self] in
            self?.refreshRetryWorkItem = nil
            self?.refreshLongPressRecognizers()
        }
        refreshRetryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
    }

    private func captureMetrics() -> Metrics? {
        guard let referenceView = view.window ?? view.superview ?? view else { return nil }
        referenceView.layoutIfNeeded()
        view.layoutIfNeeded()
        tabBar.layoutIfNeeded()
        let container = view.convert(view.bounds, to: referenceView)
        let bar = tabBar.convert(tabBar.bounds, to: referenceView)
        return Metrics(containerFrame: container,
                       tabBarFrame: bar,
                       containerSafeAreaInsets: view.safeAreaInsets,
                       tabBarSafeAreaInsets: tabBar.safeAreaInsets)
    }

    private func emitMetricsIfNeeded(force: Bool = false) {
        guard let metrics = captureMetrics() else { return }
        onMetricsChanged?(metrics)
    }

    func notifyMetricsChanged(force: Bool = false) {
        emitMetricsIfNeeded(force: force)
    }

    func currentMetrics() -> Metrics? {
        return captureMetrics()
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
        DispatchQueue.main.async { [weak self] in
            self?.refreshLongPressRecognizers()
            self?.emitMetricsIfNeeded(force: true)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyInterfaceStyle()
        notifyMetricsChanged(force: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        DispatchQueue.main.async { [weak self] in
            self?.refreshLongPressRecognizers()
            self?.emitMetricsIfNeeded()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        menuPresenter.dismiss(animated: false)
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        applyTitleColors()
        refreshMenuPresenterTheme()
        DispatchQueue.main.async { [weak self] in
            self?.refreshLongPressRecognizers()
            self?.emitMetricsIfNeeded()
        }
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
        menuPresenter.dismiss(animated: false)
        rebuildItems()
        applyTitleColors()
        DispatchQueue.main.async { [weak self] in self?.notifyMetricsChanged(force: true) }
    }

    private func effectiveInterfaceStyle() -> UIUserInterfaceStyle {
        let style = forcedInterfaceStyle == .unspecified ? traitCollection.userInterfaceStyle : forcedInterfaceStyle
        return style
    }

    private func resolveColor(from set: MenuColorSet, style: UIUserInterfaceStyle) -> UIColor? {
        switch style {
        case .dark:
            return HexUtil.color(set.dark)
        default:
            return HexUtil.color(set.light)
        }
    }

    private func fallbackTitleColor(for index: Int, style: UIUserInterfaceStyle) -> UIColor? {
        let palette = perTabTitles[index] ?? globalTitles
        let pick: String?
        if style == .dark {
            pick = palette.darkNormal ?? palette.darkSelected ?? palette.darkDisabled
        } else {
            pick = palette.lightNormal ?? palette.lightSelected ?? palette.lightDisabled
        }
        return HexUtil.color(pick) ?? UIColor.label
    }

    func setContextMenuTitleColors(light: String?, dark: String?) {
        menuTitleColors = MenuColorSet(light: light, dark: dark)
        refreshMenuPresenterTheme()
    }

    func setContextMenuSubtitleColors(light: String?, dark: String?) {
        menuSubtitleColors = MenuColorSet(light: light, dark: dark)
        refreshMenuPresenterTheme()
    }

    func setContextMenuBackgroundTint(light: String?, dark: String?) {
        menuBackgroundTint = MenuColorSet(light: light, dark: dark)
        refreshMenuPresenterTheme()
    }

    private func refreshMenuPresenterTheme(forcedIndex: Int? = nil) {
        let style = effectiveInterfaceStyle()
        let targetIndex = forcedIndex ?? selectedIndex
        let resolvedIndex: Int? = items.isEmpty ? nil : max(0, min(targetIndex, items.count - 1))
        let fallbackTitle = resolvedIndex.flatMap { fallbackTitleColor(for: $0, style: style) } ?? UIColor.label
        let titleColor = resolveColor(from: menuTitleColors, style: style) ?? fallbackTitle
        let subtitleColor = resolveColor(from: menuSubtitleColors, style: style) ?? UIColor.secondaryLabel
        let highlightBase: String?
        if let index = resolvedIndex {
            highlightBase = perTabColors[index]?.selected ?? globalColors.selected
        } else {
            highlightBase = globalColors.selected
        }
        let highlightColor = HexUtil.color(highlightBase) ?? (style == .dark ? UIColor.systemBlue : UIColor.systemBlue)
        let backgroundColor = resolveColor(from: menuBackgroundTint, style: style)
        menuPresenter.updateColors(style: style, titleColor: titleColor, subtitleColor: subtitleColor, highlightColor: highlightColor, backgroundColor: backgroundColor)
    }

    private func handleMenuDismissed() {
        suppressSelectionFromLongPress = false
        guard longPressEnabled, !tabBarLocked else { return }
        DispatchQueue.main.async { [weak self] in
            self?.refreshLongPressRecognizers()
            self?.emitMetricsIfNeeded()
        }
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
        if tabBarLocked {
            tabBar.items?.forEach { $0.isEnabled = false }
        }
        DispatchQueue.main.async { [weak self] in
            self?.refreshLongPressRecognizers()
            self?.notifyMetricsChanged(force: true)
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

    func setLongPress(enabled: Bool) {
        longPressEnabled = enabled
        updateLongPressRecognizerStates()
        if !enabled {
            menuPresenter.dismiss(animated: false)
        }
        DispatchQueue.main.async { [weak self] in self?.refreshLongPressRecognizers() }
    }
    func setTabBarLocked(_ locked: Bool) {
        tabBarLocked = locked
        tabBar.isUserInteractionEnabled = !locked
        if locked {
            cachedItemEnabledStates.removeAll()
            tabBar.items?.enumerated().forEach { index, item in
                cachedItemEnabledStates[index] = item.isEnabled
                item.isEnabled = false
            }
            menuPresenter.dismiss(animated: false)
        }
        if !locked {
            tabBar.items?.enumerated().forEach { index, item in
                if let previous = cachedItemEnabledStates[index] {
                    item.isEnabled = previous
                } else {
                    item.isEnabled = true
                }
            }
            cachedItemEnabledStates.removeAll()
        }
        updateLongPressRecognizerStates()
        if !locked {
            DispatchQueue.main.async { [weak self] in self?.refreshLongPressRecognizers() }
        }
    }
    func setContextMenu(index: Int, items: [ContextItem]) { perTabCtx[index] = items }
    func setDefaultContextMenu(items: [ContextItem]) {
        defaultCtx = items
        if items.isEmpty {
            menuPresenter.dismiss(animated: false)
        }
    }

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

    private func refreshLongPressRecognizers() {
        refreshRetryWorkItem?.cancel()
        refreshRetryWorkItem = nil
        buttonLongPressRecognizers.forEach { recognizer in
            recognizer.view?.removeGestureRecognizer(recognizer)
        }
        buttonLongPressRecognizers.removeAll()

        guard longPressEnabled, !tabBarLocked else { return }

        tabBar.layoutIfNeeded()

        guard let tabItems = tabBar.items, !tabItems.isEmpty else { return }
        var mapping: [(UIView, Int)] = []

        for (index, item) in tabItems.enumerated() {
            if let view = item.value(forKey: "view") as? UIView {
                mapping.append((view, index))
            }
        }

        if mapping.count != tabItems.count {
            if let buttonClass = NSClassFromString("UITabBarButton") {
                let buttonViews = tabBar.subviews
                    .filter { $0.isKind(of: buttonClass) }
                    .sorted { $0.frame.minX < $1.frame.minX }
                if buttonViews.count == tabItems.count {
                    mapping = buttonViews.enumerated().map { ($0.element, $0.offset) }
                }
            }
        }

        guard !mapping.isEmpty else {
            scheduleLongPressRefreshRetry()
            return
        }

        for (view, index) in mapping {
            view.tag = index
            let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleButtonLongPress(_:)))
            recognizer.minimumPressDuration = 0.33
            recognizer.allowableMovement = 20
            recognizer.cancelsTouchesInView = true
            recognizer.delegate = self
            recognizer.isEnabled = longPressEnabled && !tabBarLocked
            view.addGestureRecognizer(recognizer)
            buttonLongPressRecognizers.append(recognizer)
        }
        updateLongPressRecognizerStates()
    }

    @objc private func handleButtonLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard longPressEnabled, !tabBarLocked, recognizer.state == .began else { return }
        guard let index = recognizer.view?.tag, index >= 0 else { return }
        let menuItems = perTabCtx[index] ?? defaultCtx
        guard !menuItems.isEmpty else { return }
        suppressSelectionFromLongPress = true
        if let items = tabBar.items, selectedIndex >= 0, selectedIndex < items.count {
            tabBar.selectedItem = items[selectedIndex]
        }
        let presented = presentMenu(at: index, items: menuItems)
        if !presented {
            suppressSelectionFromLongPress = false
        }
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

    @discardableResult
    func presentMenu(at index: Int, items precomputedItems: [ContextItem]? = nil) -> Bool {
        guard index >= 0, index < items.count else { return false }
        guard !tabBarLocked else { return false }
        let menuItems = precomputedItems ?? perTabCtx[index] ?? defaultCtx
        guard !menuItems.isEmpty else { return false }

        let route = items[index].route
        onLongPress?(index, route)

        guard let hostView = view.window ?? view.superview ?? view else { return false }

        let style = effectiveInterfaceStyle()
        let titleColor = resolveColor(from: menuTitleColors, style: style) ?? fallbackTitleColor(for: index, style: style) ?? UIColor.label
        let subtitleColor = resolveColor(from: menuSubtitleColors, style: style) ?? UIColor.secondaryLabel
        let highlightColor = HexUtil.color(perTabColors[index]?.selected ?? globalColors.selected) ?? (style == .dark ? UIColor.systemBlue : UIColor.systemBlue)
        let backgroundColor = resolveColor(from: menuBackgroundTint, style: style)

        menuPresenter.present(over: hostView,
                              tabBar: tabBar,
                              items: menuItems,
                              tabIndex: index,
                              route,
                              style: style,
                              titleColor: titleColor,
                              subtitleColor: subtitleColor,
                              highlightColor: highlightColor,
                              backgroundColor: backgroundColor,
                              onSelect: { [weak self] itemId in
                                  self?.onContextItem?(index, itemId)
                              },
                              onDismiss: { [weak self] in
                                  self?.handleMenuDismissed()
                              })
        return true
    }

    // MARK: - UIGestureRecognizerDelegate
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        if suppressSelectionFromLongPress {
            suppressSelectionFromLongPress = false
            if selectedIndex >= 0, let items = tabBar.items, selectedIndex < items.count {
                tabBar.selectedItem = items[selectedIndex]
            }
            return
        }
        let idx = item.tag
        guard idx >= 0, idx < items.count else { return }
        let route = items[idx].route
        let reselect = (idx == selectedIndex)
        selectedIndex = idx
        onSelect?(idx, route, reselect)
    }
}

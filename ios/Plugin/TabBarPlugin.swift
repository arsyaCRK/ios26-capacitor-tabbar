// TabBarPlugin.swift (no animation methods)
import Foundation
import Capacitor
import UIKit

@objc(MmsmartCapacitorIos26Tabbar)
public class TabBarPlugin: CAPPlugin {

  private var host: NativeTabBarController?
  private var containerHeightConstraint: NSLayoutConstraint?
  private var leadingConstraint: NSLayoutConstraint?
  private var trailingConstraint: NSLayoutConstraint?
  private var bottomConstraint: NSLayoutConstraint?
  private var usesSafeArea = false
  private var pendingInterfaceStyle: UIUserInterfaceStyle = .unspecified
  private var currentBottomInset: CGFloat = 24

  struct IconColors: Codable { let normal: String?; let selected: String?; let disabled: String? }
  struct TitleSide: Codable { let normal: String?; let selected: String?; let disabled: String? }
  struct TitleColors: Codable { let light: TitleSide?; let dark: TitleSide? }
  struct CtxItem: Codable { let id: String; let title: String; let subtitle: String?; let sfSymbol: String? }
  struct TabItem: Codable { let title: String; let icon: String; let route: String; let badge: String?; let iconColors: IconColors?; let contextMenuItems: [CtxItem]?; let titleColors: TitleColors? }
  struct LayoutCfg: Codable { let position: String?; let bottomInset: CGFloat?; let sideInset: CGFloat? }
  struct CtxCfg: Codable { let longPressEnabled: Bool?; let defaultItems: [CtxItem]? }
  struct ShowOptions: Codable { let tabs: [TabItem]; let selectedIndex: Int?; let layout: LayoutCfg?; let iconColors: IconColors?; let titleColors: TitleColors?; let contextMenu: CtxCfg? }

  private func decode<T: Decodable>(_ obj: Any, as: T.Type) throws -> T {
    let data = try JSONSerialization.data(withJSONObject: obj, options: [])
    return try JSONDecoder().decode(T.self, from: data)
  }

  private func titlePaletteFrom(_ t: TitleColors?) -> NativeTabBarController.TitlePalette? {
    guard let t = t else { return nil }
    return NativeTabBarController.TitlePalette(
      lightNormal: t.light?.normal, lightSelected: t.light?.selected, lightDisabled: t.light?.disabled,
      darkNormal:  t.dark?.normal,  darkSelected:  t.dark?.selected,  darkDisabled:  t.dark?.disabled
    )
  }

  
  private func computeBottomConstant(for bridgeVC: UIViewController, respectSafeArea: Bool, inset: CGFloat) -> CGFloat {
    guard respectSafeArea else { return -inset }
    guard let containerView = bridgeVC.view else { return -inset }
    containerView.layoutIfNeeded()
    var safeInset = containerView.safeAreaInsets.bottom
    if safeInset == 0, let windowInset = containerView.window?.safeAreaInsets.bottom {
      safeInset = windowInset
    }
    if safeInset == 0 {
      let scenes = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
      for scene in scenes {
        for window in scene.windows where window.isKeyWindow {
          safeInset = window.safeAreaInsets.bottom
          if safeInset > 0 { break }
        }
        if safeInset > 0 { break }
      }
    }
    return safeInset - inset
  }

  private func replaceBottomConstraint(respectSafeArea: Bool, inset: CGFloat) {
    guard let bridgeVC = self.bridge?.viewController, let hostView = self.host?.view else { return }
    // remove old
    if let bc = self.bottomConstraint {
      bc.isActive = false
      hostView.removeConstraint(bc)
    }
    self.usesSafeArea = respectSafeArea
    self.currentBottomInset = inset
    if respectSafeArea {
      let constant = computeBottomConstant(for: bridgeVC, respectSafeArea: true, inset: inset)
      self.bottomConstraint = hostView.bottomAnchor.constraint(equalTo: bridgeVC.view.safeAreaLayoutGuide.bottomAnchor, constant: constant)
    } else {
      self.bottomConstraint = hostView.bottomAnchor.constraint(equalTo: bridgeVC.view.bottomAnchor, constant: -inset)
    }
    self.bottomConstraint?.isActive = true
    bridgeVC.view.layoutIfNeeded()
  }

  private func attachIfNeeded(_ c: NativeTabBarController, _ bottomInset: CGFloat, _ sideInset: CGFloat) {
    guard let bridgeVC = self.bridge?.viewController else { return }
    c.view.translatesAutoresizingMaskIntoConstraints = false
    if self.host == nil {
      bridgeVC.addChild(c)
      bridgeVC.view.addSubview(c.view)
      c.didMove(toParent: bridgeVC)

      let height: CGFloat = 104
      self.containerHeightConstraint = c.view.heightAnchor.constraint(equalToConstant: height)
      self.containerHeightConstraint?.isActive = true

      self.leadingConstraint = c.view.leadingAnchor.constraint(equalTo: bridgeVC.view.leadingAnchor, constant: sideInset)
      self.trailingConstraint = c.view.trailingAnchor.constraint(equalTo: bridgeVC.view.trailingAnchor, constant: -sideInset)
      if self.usesSafeArea {
        let constant = computeBottomConstant(for: bridgeVC, respectSafeArea: true, inset: bottomInset)
        self.bottomConstraint = c.view.bottomAnchor.constraint(equalTo: bridgeVC.view.safeAreaLayoutGuide.bottomAnchor, constant: constant)
      } else {
        self.bottomConstraint = c.view.bottomAnchor.constraint(equalTo: bridgeVC.view.bottomAnchor, constant: -bottomInset)
      }
      NSLayoutConstraint.activate([ self.leadingConstraint!, self.trailingConstraint!, self.bottomConstraint! ])

      bridgeVC.view.bringSubviewToFront(c.view)
    }
  }

  @objc public func show(_ call: CAPPluginCall) {
    DispatchQueue.main.async {
      do {
        let opts: ShowOptions = try self.decode(call.options, as: ShowOptions.self)

        let tabs = opts.tabs.map { t in
          NativeTabBarController.TabItem(
            title: t.title, sfSymbol: t.icon, route: t.route, badge: t.badge,
            iconColors: t.iconColors.map { NativeTabBarController.IconColors(normal: $0.normal, selected: $0.selected, disabled: $0.disabled) },
            ctxItems: t.contextMenuItems?.map { NativeTabBarController.ContextItem(id: $0.id, title: $0.title, subtitle: $0.subtitle, sfSymbol: $0.sfSymbol) },
            titlePalette: self.titlePaletteFrom(t.titleColors)
          )
        }

        let selected = opts.selectedIndex ?? 0
        let bottomInset = opts.layout?.bottomInset ?? 24
        let sideInset = opts.layout?.sideInset ?? 16
        let position = opts.layout?.position ?? "absolute"
        self.usesSafeArea = (position == "safe-area")
        self.currentBottomInset = bottomInset

        let c = self.host ?? NativeTabBarController()
        c.setInterfaceStyle(self.pendingInterfaceStyle)
        c.onSelect = { [weak self] idx, route, reselection in
          guard let self else { return }
          self.notifyListeners(reselection ? "tabReselected" : "tabSelected", data: ["index": idx, "route": route])
        }
        c.onLongPress = { [weak self] idx, route in self?.notifyListeners("tabLongPress", data: ["index": idx, "route": route]) }
        c.onContextItem = { [weak self] idx, itemId in self?.notifyListeners("contextMenuItemSelected", data: ["index": idx, "itemId": itemId]) }

        self.attachIfNeeded(c, bottomInset, sideInset)

        if let gc = opts.iconColors {
          c.setGlobalColors(NativeTabBarController.IconColors(normal: gc.normal, selected: gc.selected, disabled: gc.disabled))
        }
        if let tc = opts.titleColors, let pal = self.titlePaletteFrom(tc) {
          c.setGlobalTitlePalette(pal)
        }
        c.setLongPress(enabled: opts.contextMenu?.longPressEnabled ?? true)
        if let defItems = opts.contextMenu?.defaultItems {
          let mapped = defItems.map { NativeTabBarController.ContextItem(id: $0.id, title: $0.title, subtitle: $0.subtitle, sfSymbol: $0.sfSymbol) }
          c.setDefaultContextMenu(items: mapped)
        }

        c.configure(tabs: tabs, selected: selected)
        self.host = c
        call.resolve()
      } catch {
        call.reject("Invalid options: \(error)")
      }
    }
  }

  
  @objc public func setBottomOffset(_ call: CAPPluginCall) {
    DispatchQueue.main.async {
      let inset = CGFloat(call.getDouble("bottomInset") ?? 0)
      let pos = call.getString("position") ?? (self.usesSafeArea ? "safe-area" : "absolute")
      let respect = (pos == "safe-area")
      self.replaceBottomConstraint(respectSafeArea: respect, inset: inset)
      call.resolve()
    }
  }


  @objc public func setLayout(_ call: CAPPluginCall) {
    DispatchQueue.main.async {
      let previousUsesSafeArea = self.usesSafeArea
      if let pos = call.getString("position") {
        self.usesSafeArea = (pos == "safe-area")
      }
      if let bi = call.getDouble("bottomInset") {
        self.currentBottomInset = CGFloat(bi)
      }
      if self.usesSafeArea != previousUsesSafeArea {
        self.replaceBottomConstraint(respectSafeArea: self.usesSafeArea, inset: self.currentBottomInset)
      } else if call.getDouble("bottomInset") != nil {
        if self.usesSafeArea, let bridgeVC = self.bridge?.viewController {
          let constant = self.computeBottomConstant(for: bridgeVC, respectSafeArea: true, inset: self.currentBottomInset)
          self.bottomConstraint?.constant = constant
        } else {
          self.bottomConstraint?.constant = -self.currentBottomInset
        }
      }
      if let si = call.getDouble("sideInset") {
        self.leadingConstraint?.constant = CGFloat(si)
        self.trailingConstraint?.constant = CGFloat(-si)
      }
      self.bridge?.viewController?.view.layoutIfNeeded()
      call.resolve()
    }
  }

  @objc public func setUserInterfaceStyle(_ call: CAPPluginCall) {
    DispatchQueue.main.async {
      let styleValue = (call.getString("style") ?? "auto").lowercased()
      let resolved: UIUserInterfaceStyle
      switch styleValue {
      case "light":
        resolved = .light
      case "dark":
        resolved = .dark
      default:
        resolved = .unspecified
      }
      self.pendingInterfaceStyle = resolved
      self.host?.setInterfaceStyle(resolved)
      call.resolve()
    }
  }

  @objc public func hide(_ call: CAPPluginCall) {
    DispatchQueue.main.async {
      self.containerHeightConstraint?.isActive = false
      self.containerHeightConstraint = nil
      self.leadingConstraint = nil; self.trailingConstraint = nil; self.bottomConstraint = nil
      self.host?.view.removeFromSuperview()
      self.host?.removeFromParent()
      self.host = nil
      call.resolve()
    }
  }

  @objc public func select(_ call: CAPPluginCall) {
    DispatchQueue.main.async {
      let idx = call.getInt("index") ?? 0
      guard let ok = self.host?.select(index: idx), ok else { call.reject("index out of bounds"); return }
      call.resolve()
    }
  }

  @objc public func setBadge(_ call: CAPPluginCall) {
    DispatchQueue.main.async {
      let idx = call.getInt("index") ?? -1
      guard idx >= 0 else { call.reject("index required"); return }
      let value = call.getString("value")
      self.host?.setBadge(index: idx, value: value)
      call.resolve()
    }
  }

  @objc public func setIconColors(_ call: CAPPluginCall) {
    DispatchQueue.main.async {
      let normal = call.getString("normal")
      let selected = call.getString("selected")
      let disabled = call.getString("disabled")
      self.host?.setGlobalColors(NativeTabBarController.IconColors(normal: normal, selected: selected, disabled: disabled))
      call.resolve()
    }
  }

  @objc public func setTabIconColors(_ call: CAPPluginCall) {
    DispatchQueue.main.async {
      let idx = call.getInt("index") ?? -1
      guard idx >= 0 else { call.reject("index required"); return }
      let normal = call.getString("normal")
      let selected = call.getString("selected")
      let disabled = call.getString("disabled")
      self.host?.setTabColors(index: idx, NativeTabBarController.IconColors(normal: normal, selected: selected, disabled: disabled))
      call.resolve()
    }
  }

  @objc public func setTitleColors(_ call: CAPPluginCall) {
    DispatchQueue.main.async {
      let light = call.getObject("light")
      let dark  = call.getObject("dark")
      let p = NativeTabBarController.TitlePalette(
        lightNormal: light?["normal"] as? String, lightSelected: light?["selected"] as? String, lightDisabled: light?["disabled"] as? String,
        darkNormal:  dark?["normal"] as? String,  darkSelected:  dark?["selected"] as? String,  darkDisabled:  dark?["disabled"] as? String
      )
      self.host?.setGlobalTitlePalette(p)
      call.resolve()
    }
  }

  @objc public func setTabTitleColors(_ call: CAPPluginCall) {
    DispatchQueue.main.async {
      let idx = call.getInt("index") ?? -1
      guard idx >= 0 else { call.reject("index required"); return }
      let light = call.getObject("light")
      let dark  = call.getObject("dark")
      let p = NativeTabBarController.TitlePalette(
        lightNormal: light?["normal"] as? String, lightSelected: light?["selected"] as? String, lightDisabled: light?["disabled"] as? String,
        darkNormal:  dark?["normal"] as? String,  darkSelected:  dark?["selected"] as? String,  darkDisabled:  dark?["disabled"] as? String
      )
      self.host?.setTabTitlePalette(index: idx, p)
      call.resolve()
    }
  }

  @objc public func setLongPressEnabled(_ call: CAPPluginCall) {
    DispatchQueue.main.async {
      self.host?.setLongPress(enabled: call.getBool("enabled") ?? true)
      call.resolve()
    }
  }

  @objc public func setContextMenuForIndex(_ call: CAPPluginCall) {
    DispatchQueue.main.async {
      let idx = call.getInt("index") ?? -1
      guard idx >= 0 else { call.reject("index required"); return }
      guard let raw = call.options["items"] else { call.reject("items required"); return }
      do {
        let data = try JSONSerialization.data(withJSONObject: raw, options: [])
        let items = try JSONDecoder().decode([CtxItem].self, from: data)
        let mapped = items.map { NativeTabBarController.ContextItem(id: $0.id, title: $0.title, subtitle: $0.subtitle, sfSymbol: $0.sfSymbol) }
        self.host?.setContextMenu(index: idx, items: mapped)
        call.resolve()
      } catch {
        call.reject("bad items: \(error)")
      }
    }
  }

  @objc public func presentContextMenu(_ call: CAPPluginCall) {
    DispatchQueue.main.async {
      let idx = call.getInt("index") ?? -1
      guard idx >= 0 else { call.reject("index required"); return }
      self.host?.presentMenu(at: idx)
      call.resolve()
    }
  }
}

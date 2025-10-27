import { registerPlugin, Capacitor } from '@capacitor/core'
import type { TabBarPlugin } from './definitions'
export const TabBar = registerPlugin<TabBarPlugin>('MmsmartCapacitorIos26Tabbar', {
  web: () => ({
    show: async () => { console.warn('[TabBar] web shim used') },
    hide: async () => {}, select: async () => {}, setBadge: async () => {},
    setIconColors: async () => {}, setTabIconColors: async () => {},
    setTitleColors: async () => {}, setTabTitleColors: async () => {},
    setLongPressEnabled: async () => {}, getTabBarMetrics: async () => ({
      width: 0, height: 0, x: 0, y: 0,
      tabBarFrame: { x: 0, y: 0, width: 0, height: 0 },
      containerFrame: { x: 0, y: 0, width: 0, height: 0 },
      containerSafeArea: { top: 0, left: 0, bottom: 0, right: 0 },
      tabBarSafeArea: { top: 0, left: 0, bottom: 0, right: 0 },
      usesSafeArea: false, configuredBottomInset: 0,
      viewport: { width: 0, height: 0 }, selectedIndex: 0
    }), lockTabBar: async () => {}, unlockTabBar: async () => {},
    setContextMenuForIndex: async () => {},
    setContextMenuTitleColors: async () => {}, setContextMenuSubtitleColors: async () => {},
    setContextMenuBackgroundTint: async () => {},
    presentContextMenu: async () => {}, setLayout: async () => {},
    setBottomOffset: async () => {}, setUserInterfaceStyle: async () => {},
    addListener: async (_e: any, _cb: any) => ({ remove: () => {} })
  } as any)
})
if (Capacitor.getPlatform() === 'ios') console.info('[TabBar] iOS native proxy registered')
export * from './definitions'

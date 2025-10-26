import { registerPlugin, Capacitor } from '@capacitor/core'
import type { TabBarPlugin } from './definitions'
export const TabBar = registerPlugin<TabBarPlugin>('MmsmartCapacitorIos26Tabbar', {
  web: () => ({
    show: async () => { console.warn('[TabBar] web shim used') },
    hide: async () => {}, select: async () => {}, setBadge: async () => {},
    setIconColors: async () => {}, setTabIconColors: async () => {},
    setTitleColors: async () => {}, setTabTitleColors: async () => {},
    setLongPressEnabled: async () => {}, lockTabBar: async () => {}, unlockTabBar: async () => {},
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

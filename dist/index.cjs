'use strict';

const core = require('@capacitor/core');

const webShim = {
  async show () { console.warn('[TabBar] web shim used'); },
  async hide () {},
  async select () {},
  async setBadge () {},
  async setIconColors () {},
  async setTabIconColors () {},
  async setTitleColors () {},
  async setTabTitleColors () {},
  async setLongPressEnabled () {},
  async getTabBarMetrics () {
    return {
      width: 0,
      height: 0,
      x: 0,
      y: 0,
      tabBarFrame: { x: 0, y: 0, width: 0, height: 0 },
      containerFrame: { x: 0, y: 0, width: 0, height: 0 },
      containerSafeArea: { top: 0, left: 0, bottom: 0, right: 0 },
      tabBarSafeArea: { top: 0, left: 0, bottom: 0, right: 0 },
      usesSafeArea: false,
      configuredBottomInset: 0,
      viewport: { width: 0, height: 0 },
      selectedIndex: 0
    };
  },
  async lockTabBar () {},
  async unlockTabBar () {},
  async setContextMenuForIndex () {},
  async setContextMenuTitleColors () {},
  async setContextMenuSubtitleColors () {},
  async setContextMenuBackgroundTint () {},
  async presentContextMenu () {},
  async setLayout () {},
  async setBottomOffset () {},
  async setUserInterfaceStyle () {},
  async addListener () { return { remove () {} }; }
};

const TabBar = core.registerPlugin('MmsmartCapacitorIos26Tabbar', {
  web: () => webShim
});

if (core.Capacitor.getPlatform() === 'ios') {
  console.info('[TabBar] iOS native proxy registered');
}

module.exports = {
  TabBar
};

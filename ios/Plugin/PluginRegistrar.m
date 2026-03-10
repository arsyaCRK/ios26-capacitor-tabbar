// PluginRegistrar.m (no animation methods)
#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>
CAP_PLUGIN(MmsmartCapacitorIos26Tabbar, "MmsmartCapacitorIos26Tabbar",
  CAP_PLUGIN_METHOD(show, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(hide, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(select, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(setBadge, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(setIconColors, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(setTabIconColors, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(setTitleColors, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(setTabTitleColors, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(setLongPressEnabled, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(getTabBarMetrics, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(lockTabBar, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(unlockTabBar, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(setContextMenuForIndex, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(setContextMenuTitleColors, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(setContextMenuSubtitleColors, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(setContextMenuBackgroundTint, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(setLayout, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(setBottomOffset, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(setUserInterfaceStyle, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(presentContextMenu, CAPPluginReturnPromise);
)

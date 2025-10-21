export type HexColor = `#${string}`;
export interface ContextMenuItem { id: string; title: string; subtitle?: string; sfSymbol?: string }
export interface IconColors { normal?: HexColor; selected?: HexColor; disabled?: HexColor }
export interface TitleColors { light?: { normal?: HexColor; selected?: HexColor; disabled?: HexColor }; dark?: { normal?: HexColor; selected?: HexColor; disabled?: HexColor } }
export interface TabItem { title: string; icon: string; route: string; badge?: string; iconColors?: IconColors; contextMenuItems?: ContextMenuItem[]; titleColors?: TitleColors }
export interface ShowOptions { tabs: TabItem[]; selectedIndex?: number; layout?: { position?: 'absolute'|'safe-area'; bottomInset?: number; sideInset?: number }; iconColors?: IconColors; titleColors?: TitleColors; contextMenu?: { longPressEnabled?: boolean; defaultItems?: ContextMenuItem[] } }
export type UserInterfaceStyle = 'light' | 'dark' | 'auto';
export interface TabBarPlugin {
  show(options: ShowOptions): Promise<void>; hide(): Promise<void>; select(options: { index: number }): Promise<void>; setBadge(options: { index: number; value?: string }): Promise<void>;
  setIconColors(options: IconColors): Promise<void>; setTabIconColors(options: IconColors & { index: number }): Promise<void>;
  setTitleColors(options: TitleColors): Promise<void>; setTabTitleColors(options: TitleColors & { index: number }): Promise<void>;
  setLongPressEnabled(options: { enabled: boolean }): Promise<void>; setContextMenuForIndex(options: { index: number; items: ContextMenuItem[] }): Promise<void>;
  setLayout(options: { position?: 'absolute'|'safe-area'; bottomInset?: number; sideInset?: number }): Promise<void>;
  setBottomOffset(options: { bottomInset: number; position?: 'absolute'|'safe-area' }): Promise<void>;
  presentContextMenu(options: { index: number }): Promise<void>;
  setContextMenuTitleColors(options: { light?: HexColor; dark?: HexColor }): Promise<void>;
  setContextMenuSubtitleColors(options: { light?: HexColor; dark?: HexColor }): Promise<void>;
  setContextMenuBackgroundTint(options: { light?: HexColor; dark?: HexColor }): Promise<void>;
  setUserInterfaceStyle(options: { style: UserInterfaceStyle }): Promise<void>;
  addListener(eventName: 'tabSelected', listenerFunc: (data: { index: number; route: string }) => void): Promise<{ remove: () => void }>;
  addListener(eventName: 'tabReselected', listenerFunc: (data: { index: number; route: string }) => void): Promise<{ remove: () => void }>;
  addListener(eventName: 'tabLongPress', listenerFunc: (data: { index: number; route: string }) => void): Promise<{ remove: () => void }>;
  addListener(eventName: 'contextMenuItemSelected', listenerFunc: (data: { index: number; itemId: string }) => void): Promise<{ remove: () => void }>;
}

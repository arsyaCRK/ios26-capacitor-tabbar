# @mmsmart/capacitor-ios26-tabbar

Нативный **UITabBar** для Capacitor с внешним видом в стиле **iOS 26 (glass)**. Плагин написан на UIKit (без SwiftUI), поддерживает iOS 13+ и включает:

- Стеклянный вид (blur + прозрачный фон) как в iOS 26.
- Отдельные **цвета иконок** (normal/selected/disabled), глобально и для каждого таба.
- Отдельные **цвета подписей под иконками** (light/dark, normal/selected/disabled), глобально и для каждого таба.
- **Контекстное меню** по долгому нажатию (LongPress) на элементы таббара — per‑tab.
- **Бейджи** на табах.
- **Runtime‑layout**: можно задать отступ от нижнего края и боковые отступы (позиция абсолютная).
- Принудительный выбор темы таббара: `light`, `dark` или `auto` (следовать системе).
- События: `tabSelected`, `tabReselected`, `tabLongPress`, `contextMenuItemSelected`.

> В версии **1.1.4+** полностью удалены API анимации иконок (символьные эффекты).

---

## Установка

```bash
# локальная установка из tgz-архива
npm i ./mmsmart-capacitor-ios26-tabbar-1.1.6-prebuilt-rootpod.tgz

# синхронизация Capacitor
npx cap sync ios

# установка CocoaPods
cd ios && pod install
```

### Требования

- **iOS 13+**
- **Capacitor 5 или 6**
- Xcode 15+ (рекомендуется)

### Замечание по Podfile (rootpod)

Плагин содержит Podspec в корне, поэтому в большинстве проектов дополнительная правка `Podfile` не требуется.  
Если же у вас кастомный `Podfile` и **Capacitor** удаляет строку плагина при `npx cap sync ios`, добавьте её вручную внутри `target 'App' do`:

```ruby
pod 'MmsmartCapacitorIos26Tabbar', :path => '../../node_modules/@mmsmart/capacitor-ios26-tabbar'
```

После этого выполните:
```bash
cd ios && pod install
```

---

## Быстрый старт (Vue 2 + Capacitor)

```ts
// App.vue (фрагмент)
import { Capacitor } from '@capacitor/core'
import { TabBar } from '@mmsmart/capacitor-ios26-tabbar'

export default {
  async mounted () {
    if (Capacitor.getPlatform() !== 'ios') return

    await TabBar.show({
      tabs: [
        { title: 'Домой',   icon: 'house.fill', route: '/home' },
        { title: 'Устройства', icon: 'dot.radiowaves.left.and.right', route: '/devices' },
        { title: 'Сцены',   icon: 'square.grid.2x2', route: '/scenes' },
        { title: 'Профиль', icon: 'person.crop.circle', route: '/profile' }
      ],
      selectedIndex: 0,
      layout: { bottomInset: 24, sideInset: 16 },
      iconColors: { normal: '#9AA0A6', selected: '#0A84FF' },
      titleColors: {
        light: { normal: '#6B7280', selected: '#0A84FF' },
        dark:  { normal: '#9AA0A6', selected: '#0A84FF' }
      },
      contextMenu: { longPressEnabled: true }
    })

    // Синхронизация с роутером
    TabBar.addListener('tabSelected', ({ index, route }) => {
      if (this.$route.path !== route) this.$router.push(route)
    })
    TabBar.addListener('tabReselected', ({ index, route }) => {
      // Доп. поведение при повторном выборе активного таба (скролл к началу и т.п.)
    })
    TabBar.addListener('tabLongPress', ({ index, route }) => {
      // показать собственный action sheet или логирование
    })
    TabBar.addListener('contextMenuItemSelected', ({ index, itemId }) => {
      // обработка выбора пункта из контекстного меню
    })
  }
}
```

---

## API

Все методы доступны через объект `TabBar` из пакета `@mmsmart/capacitor-ios26-tabbar`.

### `show(options: ShowOptions): Promise<void>`

Показывает нативный таббар.

**Параметры**

```ts
type HexColor = `#${string}`;

interface ContextMenuItem {
  id: string;
  title: string;
  subtitle?: string;
  sfSymbol?: string; // имя системной SF-иконки
}

interface IconColors {
  normal?: HexColor;
  selected?: HexColor;
  disabled?: HexColor;
}

interface TitleColors {
  light?: { normal?: HexColor; selected?: HexColor; disabled?: HexColor };
  dark?:  { normal?: HexColor; selected?: HexColor; disabled?: HexColor };
}

interface TabItem {
  title: string;
  icon: string;          // имя SF Symbol, например 'house.fill'
  route: string;         // строка маршрута для вашего роутера
  badge?: string;        // строка бейджа; пустая строка или undefined — скрыть
  iconColors?: IconColors;
  titleColors?: TitleColors;
  contextMenuItems?: ContextMenuItem[]; // пункты контекстного меню только для этого таба
}

interface ShowOptions {
  tabs: TabItem[];
  selectedIndex?: number; // индекс активного таба по умолчанию
  layout?: {
    position?: 'absolute' | 'safe-area'; // сейчас используется абсолютная позиция
    bottomInset?: number; // отступ от нижнего края экрана (по умолчанию 24)
    sideInset?: number;   // боковые отступы (по умолчанию 16)
  };
  iconColors?: IconColors;    // глобальные цвета иконок
  titleColors?: TitleColors;  // глобальные цвета подписей
  contextMenu?: {
    longPressEnabled?: boolean;       // включить долгий тап (по умолчанию true)
    defaultItems?: ContextMenuItem[]; // дефолтные пункты контекстного меню для всех табов
  };
}
```

**Пример**

```ts
await TabBar.show({
  tabs: [
    { title: 'Домой', icon: 'house.fill', route: '/home' },
    { title: 'Избранное', icon: 'star.fill', route: '/favorites', badge: '3' },
    { title: 'Уведомления', icon: 'bell', route: '/notifications' },
    { title: 'Настройки', icon: 'gearshape', route: '/settings' }
  ],
  selectedIndex: 0,
  layout: { bottomInset: 20, sideInset: 16 },
  iconColors: { normal: '#8E8E93', selected: '#0A84FF' },
  titleColors: {
    light: { normal: '#6B7280', selected: '#0A84FF' },
    dark:  { normal: '#9AA0A6', selected: '#0A84FF' }
  },
  contextMenu: {
    longPressEnabled: true,
    defaultItems: [
      { id: 'refresh', title: 'Обновить', sfSymbol: 'arrow.clockwise' },
      { id: 'pin',     title: 'Закрепить', sfSymbol: 'pin' }
    ]
  }
})
```

---

### `hide(): Promise<void>`

Скрывает и отсоединяет таббар от иерархии контроллеров (очищает внутренние ссылки и констрейнты).

```ts
await TabBar.hide()
```

---

### `select({ index }: { index: number }): Promise<void>`

Программно выбирает таб по индексу. Сгенерирует событие `tabSelected` или `tabReselected` в зависимости от текущего состояния.

```ts
await TabBar.select({ index: 2 })
```

---

### `setBadge({ index, value }: { index: number; value?: string }): Promise<void>`

Устанавливает/сбрасывает бейдж на табе.

```ts
await TabBar.setBadge({ index: 1, value: '7' })  // показать "7"
await TabBar.setBadge({ index: 1, value: '' })   # скрыть бейдж
```

---

### `setIconColors(colors: IconColors): Promise<void>`

Задаёт **глобальные** цвета иконок.

```ts
await TabBar.setIconColors({
  normal: '#9AA0A6',
  selected: '#0A84FF',
  disabled: '#C7C7CC'
})
```

### `setTabIconColors({ index, ...colors }): Promise<void>`

Задаёт цвета иконок **для конкретного таба** (перекрывают глобальные).

```ts
await TabBar.setTabIconColors({
  index: 2,
  normal: '#6B7280',
  selected: '#34C759'
})
```

---

### `setTitleColors(palette: TitleColors): Promise<void>`

Задаёт **глобальные** цвета подписей под иконками (учитывается светлая/тёмная тема, а также состояние selected/normal/disabled).

```ts
await TabBar.setTitleColors({
  light: { normal: '#6B7280', selected: '#0A84FF', disabled: '#C7C7CC' },
  dark:  { normal: '#9AA0A6', selected: '#0A84FF', disabled: '#5A5A5E' }
})
```

### `setTabTitleColors({ index, ...palette }): Promise<void>`

Задаёт цвета подписей **для конкретного таба**.

```ts
await TabBar.setTabTitleColors({
  index: 0,
  light: { normal: '#8E8E93', selected: '#0A84FF' },
  dark:  { normal: '#9AA0A6', selected: '#0A84FF' }
})
```

---

### `setLongPressEnabled({ enabled }: { enabled: boolean }): Promise<void>`

Включает/выключает обработку долгого нажатия на элементы таббара.

```ts
await TabBar.setLongPressEnabled({ enabled: true })
```

---

### `lockTabBar(): Promise<void>`

Полностью блокирует взаимодействие пользователя с таббаром и его контекстными меню (тапы и долгие нажатия игнорируются до разблокировки).

```ts
await TabBar.lockTabBar()
```

### `unlockTabBar(): Promise<void>`

Снимает блокировку, возвращая возможность тапать по вкладкам и вызывать контекстное меню.

```ts
await TabBar.unlockTabBar()
```

---

### `setContextMenuForIndex({ index, items }: { index: number; items: ContextMenuItem[] }): Promise<void>`

Назначает **контекстное меню** только для указанного таба (перекрывает `defaultItems` из `show`).

```ts
await TabBar.setContextMenuForIndex({
  index: 1,
  items: [
    { id: 'refresh', title: 'Обновить', sfSymbol: 'arrow.clockwise' },
    { id: 'remove',  title: 'Удалить',  sfSymbol: 'trash' }
  ]
})
```

---

### `setContextMenuTitleColors({ light, dark }: { light?: string; dark?: string }): Promise<void>`

Задаёт цвета текста пунктов контекстного меню для светлой и тёмной темы.

```ts
await TabBar.setContextMenuTitleColors({
  light: '#000000',
  dark: '#FFFFFF'
})
```

### `setContextMenuSubtitleColors({ light, dark }: { light?: string; dark?: string }): Promise<void>`

Настраивает цвета подзаголовков (subtitle) пунктов контекстного меню.

```ts
await TabBar.setContextMenuSubtitleColors({
  light: '#6B7280',
  dark: '#B3B9C9'
})
```

### `setContextMenuBackgroundTint({ light, dark }: { light?: string; dark?: string }): Promise<void>`

Изменяет базовый тон стеклянного фона контекстного меню. Альфа-канал применяется автоматически.

```ts
await TabBar.setContextMenuBackgroundTint({
  light: '#FFFFFF',
  dark: '#0A84FF'
})
```

---

### `presentContextMenu({ index }: { index: number }): Promise<void>`

(Заглушка на iOS; меню показывается системой по LongPress автоматически. Метод оставлен для совместимости и будущих сценариев).

```ts
await TabBar.presentContextMenu({ index: 0 })
```

---

### `setLayout({ bottomInset, sideInset }: { bottomInset?: number; sideInset?: number }): Promise<void>`

Обновляет отступы во время работы приложения (позиция абсолютная, WebView не сдвигается).

- Для `position: 'safe-area'` значение `bottomInset` интерпретируется как расстояние от нижнего края экрана; необходимый запас для home-индексатора вычитается автоматически.

```ts
await TabBar.setLayout({ bottomInset: 28, sideInset: 20 })
```

---

### `setUserInterfaceStyle({ style }: { style: 'light' | 'dark' | 'auto' }): Promise<void>`

Фиксирует тему таббара и контекстных меню независимо от системного оформления. Значение `auto` (по умолчанию) возвращает поведение «следовать системе».

```ts
await TabBar.setUserInterfaceStyle({ style: 'dark' }) // жёстко тёмная тема
await TabBar.setUserInterfaceStyle({ style: 'auto' }) // снова следовать настройкам iOS/iPadOS
```

---

## События

### `tabSelected`

Вызывается при выборе таба (если это **не** повторный выбор текущего).

```ts
TabBar.addListener('tabSelected', ({ index, route }) => {
  // синхронизируйте роутер:
  if (router.currentRoute.path !== route) router.push(route)
})
```

### `tabReselected`

Повторный тап по уже активному табу.

```ts
TabBar.addListener('tabReselected', ({ index, route }) => {
  // пример: прокрутка списка вверх
})
```

### `tabLongPress`

Срабатывает в момент длительного нажатия (независимо от того, есть ли пункты меню).

```ts
TabBar.addListener('tabLongPress', ({ index, route }) => {
  console.log('Long press on tab', index, route)
})
```

### `contextMenuItemSelected`

Выбор пункта контекстного меню.

```ts
TabBar.addListener('contextMenuItemSelected', ({ index, itemId }) => {
  if (itemId === 'refresh') doRefresh()
})
```

---

## Рекомендации по маршрутам (Vue Router)

- Храните `route` у каждого таба как строку пути (`'/home'`, `'/devices'` и т.д.).
- В обработчике `tabSelected` делайте `router.push(route)`, но только если текущий путь отличается.
- Если получаете *NavigationDuplicated*, проверьте, что вы не вызываете `push()` на тот же путь.

---

## Тонкая настройка вида

Плагин использует `UITabBarAppearance`:
- Прозрачный фон + `UIBlurEffect(style: .systemUltraThinMaterial)`.
- Тени/границы скрыты.
- Цвета иконок и подписей задаются через методы API (см. выше).

---

## Android

На Android — заглушка: вызовы методов успешно резолвятся, но визуальный таббар не создаётся. Подключайте альтернативный таббар на веб‑уровне для Android.

---

## История версий (избранное)

- **1.1.5** — Полный README на русском, без изменений API.
- **1.1.4** — Полностью удалены анимации иконок.
- **1.1.3** — Исправлен синтаксис Swift, эффекты переписаны на UIKit (впоследствии удалены).
- **1.1.2** — Убран SwiftUI API, устранены типовые ошибки сборки.
- **1.1.1** — Убрана отдельная кнопка Search (separate tab).

---

## Лицензия

MIT


---

### `setBottomOffset({ bottomInset, position }: { bottomInset: number; position?: 'absolute' | 'safe-area' }): Promise<void>`

Устанавливает **вертикальный отступ** таббара от нижнего края экрана, а также режим привязки:

- `position: 'absolute'` — якорь к нижней границе окна (вне safe area).
- `position: 'safe-area'` — якорь к `safeAreaLayoutGuide.bottomAnchor` (учитывает «домик» и системные панели).

Если `position` не указан, используется текущий режим (настроенный через `show({ layout.position })` или предыдущий вызов `setBottomOffset`).

- При `position: 'safe-area'` указанный `bottomInset` трактуется как отступ от **реального края экрана**; требуемый запас под home-indicator вычитается автоматически.

```ts
// Прижать к safe area на 12pt
await TabBar.setBottomOffset({ bottomInset: 12, position: 'safe-area' })

// Прижать к самому низу (поверх safe area) на 24pt
await TabBar.setBottomOffset({ bottomInset: 24, position: 'absolute' })
```

> Замечание: `setLayout({ bottomInset, sideInset })` тоже остаётся доступным и может использоваться совместно.

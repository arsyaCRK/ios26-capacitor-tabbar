<template>
  <div class="app-shell">
    <div class="scroll-page" :style="pageStyle">
      <div v-if="!isIos" class="ios-note">
        Native tabbar from the plugin is available only on iOS. In the browser this page shows only the web layout.
      </div>

      <header class="hero-card">
        <p class="eyebrow">example-app</p>
        <h1>Native iOS tabbar over a scrollable web page</h1>
        <p class="hero-copy">
          This demo renders one long page with a white-to-black gradient background and uses the Capacitor tabbar
          plugin to jump between sections.
        </p>
      </header>

      <section
        v-for="section in sections"
        :id="section.id"
        :key="section.id"
        class="content-section"
      >
        <div class="section-card">
          <p class="section-kicker">{{ section.kicker }}</p>
          <h2>{{ section.title }}</h2>
          <p class="section-description">{{ section.description }}</p>

          <div class="section-grid">
            <article
              v-for="item in section.items"
              :key="item.title"
              class="detail-card"
            >
              <h3>{{ item.title }}</h3>
              <p>{{ item.copy }}</p>
            </article>
          </div>
        </div>
      </section>
    </div>
  </div>
</template>

<script>
import { Capacitor } from '@capacitor/core'
import { TabBar } from '@mmsmart/capacitor-ios26-tabbar'

const DEFAULT_BOTTOM_PADDING = 160

const SECTIONS = [
  {
    id: 'home',
    kicker: 'Section 01',
    title: 'Home',
    description: 'The page remains a single scrolling document. The native tabbar sits above the WebView and controls scroll positioning instead of route changes.',
    items: [
      { title: 'Single document', copy: 'No router is used here. Each tab maps to a section anchor on the same page.' },
      { title: 'Large vertical rhythm', copy: 'Generous spacing keeps the scroll behavior obvious on tall iPhones and iPads.' },
      { title: 'Native overlay', copy: 'The page itself never renders a fake tabbar. The plugin owns the native control.' }
    ]
  },
  {
    id: 'appearance',
    kicker: 'Section 02',
    title: 'Appearance',
    description: 'The demo uses a full-page vertical gradient from white to black, translucent cards, and readable typography so the tabbar can float over varied backgrounds.',
    items: [
      { title: 'Gradient backdrop', copy: 'A single background transitions from bright white to near-black across the full scroll range.' },
      { title: 'Layered surfaces', copy: 'Each section uses frosted cards with light borders to remain legible over the gradient.' },
      { title: 'SF Symbols tabs', copy: 'The native tabs use standard system symbols and color values documented in the plugin README.' }
    ]
  },
  {
    id: 'layout',
    kicker: 'Section 03',
    title: 'Layout',
    description: 'Spacing at the bottom responds to tabbar metrics so the final content never disappears underneath the native glass surface.',
    items: [
      { title: 'Safe scrolling', copy: 'The page reserves extra bottom space derived from the reported tabbar height and configured inset.' },
      { title: 'Section anchors', copy: 'Selecting a tab scrolls smoothly to the matching element id using scrollIntoView.' },
      { title: 'Reselect support', copy: 'Tapping the active tab again repositions the page to the top of the same section.' }
    ]
  },
  {
    id: 'metrics',
    kicker: 'Section 04',
    title: 'Metrics',
    description: 'The plugin emits live geometry data. This demo stores those values locally and uses them to keep the scroll layout in sync on rotation and safe-area changes.',
    items: [
      { title: 'Reactive bottom padding', copy: 'Bottom spacing is recalculated from tabbar metrics and applied directly to the scroll container.' },
      { title: 'Rotation friendly', copy: 'When iOS changes the viewport or safe area, the metrics listener updates layout without manual measurements.' },
      { title: 'Clean lifecycle', copy: 'Listeners are removed and the native tabbar is hidden when the Vue component is destroyed.' }
    ]
  }
]

export default {
  name: 'App',
  data () {
    return {
      sections: SECTIONS,
      isIos: Capacitor.getPlatform() === 'ios',
      bottomPadding: DEFAULT_BOTTOM_PADDING,
      listeners: []
    }
  },
  computed: {
    pageStyle () {
      return {
        '--bottom-padding': `${this.bottomPadding}px`
      }
    }
  },
  async mounted () {
    if (!this.isIos) return

    await this.setupTabBar()
  },
  beforeDestroy () {
    void this.teardownTabBar()
  },
  methods: {
    async setupTabBar () {
      await TabBar.show({
        tabs: [
          { title: 'Home', icon: 'house.fill', route: '#home' },
          { title: 'Appearance', icon: 'star.fill', route: '#appearance' },
          { title: 'Layout', icon: 'rectangle.3.group', route: '#layout' },
          { title: 'Metrics', icon: 'gearshape', route: '#metrics' }
        ],
        selectedIndex: 0,
        layout: { position: 'absolute', bottomInset: 24, sideInset: 16 },
        // Color Mode: здесь два подхода — `native` (системный selected-only цвет) и альтернативный `custom` ниже с полной палитрой.
        colorMode: 'native',
        iconColors: { selected: '#0A84FF' },
        // iconColors: { normal: '#8E8E93', selected: '#0A84FF' },
        // titleColors: {
        //   light: { normal: '#6B7280', selected: '#0A84FF' },
        //   dark: { normal: '#9AA0A6', selected: '#0A84FF' }
        // }
      })

      this.listeners = await Promise.all([
        TabBar.addListener('tabSelected', ({ route }) => {
          this.scrollToSection(route)
        }),
        TabBar.addListener('tabReselected', ({ route }) => {
          this.scrollToSection(route)
        }),
        TabBar.addListener('tabBarMetrics', metrics => {
          this.applyMetrics(metrics)
        })
      ])

      const metrics = await TabBar.getTabBarMetrics()
      this.applyMetrics(metrics)
    },
    async teardownTabBar () {
      await Promise.all(this.listeners.map(listener => listener.remove()))
      this.listeners = []

      if (this.isIos) {
        await TabBar.hide()
      }
    },
    scrollToSection (route, behavior = 'smooth') {
      const id = String(route || '').replace(/^#/, '')
      if (!id) return

      const section = document.getElementById(id)
      if (!section) return

      section.scrollIntoView({
        behavior,
        block: 'start'
      })
    },
    applyMetrics (metrics) {
      const height = Number(metrics && metrics.height) || 0
      const configuredBottomInset = Number(metrics && metrics.configuredBottomInset) || 0

      this.bottomPadding = height + configuredBottomInset + 32
    }
  }
}
</script>

<style scoped>
:global(html, body) {
  margin: 0;
  min-height: 100%;
}

:global(body) {
  font-family: "Avenir Next", "Segoe UI", sans-serif;
  background: #000;
  overflow-x: hidden;
}

:global(*) {
  box-sizing: border-box;
}

.app-shell {
  min-height: 100vh;
  color: #101010;
  overflow-x: hidden;
}

.scroll-page {
  width: 100%;
  max-width: 100%;
  box-sizing: border-box;
  min-height: 100vh;
  padding: 24px 16px var(--bottom-padding, 160px);
  background: linear-gradient(180deg, #ffffff 0%, #d8d8d8 28%, #7d7d7d 58%, #1d1d1d 82%, #000000 100%);
  overflow-x: hidden;
}

.ios-note,
.hero-card,
.section-card {
  width: auto;
  max-width: 960px;
  margin: 0 auto;
  box-sizing: border-box;
  border: 1px solid rgba(255, 255, 255, 0.28);
  background: rgba(255, 255, 255, 0.18);
  backdrop-filter: blur(18px);
  -webkit-backdrop-filter: blur(18px);
  box-shadow: 0 22px 60px rgba(0, 0, 0, 0.14);
}

.ios-note {
  margin-bottom: 16px;
  padding: 14px 16px;
  border-radius: 18px;
  color: #111;
  background: rgba(255, 255, 255, 0.72);
}

.hero-card {
  padding: 28px;
  border-radius: 28px;
}

.eyebrow,
.section-kicker {
  margin: 0 0 8px;
  font-size: 12px;
  letter-spacing: 0.18em;
  text-transform: uppercase;
}

.hero-card h1,
.section-card h2 {
  margin: 0;
  line-height: 0.96;
  letter-spacing: -0.04em;
}

.hero-card h1 {
  max-width: 11ch;
  font-size: clamp(44px, 10vw, 88px);
  word-break: break-word;
}

.hero-copy,
.section-description,
.detail-card p {
  line-height: 1.55;
  overflow-wrap: anywhere;
}

.hero-copy {
  max-width: 42rem;
  margin: 20px 0 0;
  font-size: 18px;
  color: rgba(16, 16, 16, 0.82);
}

.content-section {
  padding-top: 28px;
}

.section-card {
  min-height: 82vh;
  padding: 28px;
  border-radius: 28px;
}

.section-card h2 {
  font-size: clamp(36px, 8vw, 64px);
}

.section-description {
  max-width: 40rem;
  margin: 16px 0 0;
  font-size: 18px;
  color: rgba(16, 16, 16, 0.8);
}

.section-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 16px;
  margin-top: 28px;
}

.detail-card {
  min-height: 200px;
  padding: 20px;
  border-radius: 22px;
  background: rgba(255, 255, 255, 0.44);
  border: 1px solid rgba(255, 255, 255, 0.4);
}

.detail-card h3 {
  margin: 0 0 12px;
  font-size: 22px;
}

.detail-card p {
  margin: 0;
  color: rgba(16, 16, 16, 0.78);
}

@media (max-width: 640px) {
  .scroll-page {
    padding-top: 16px;
    padding-left: 12px;
    padding-right: 12px;
  }

  .hero-card,
  .section-card {
    padding: 22px;
    border-radius: 22px;
  }

  .hero-card h1 {
    max-width: 100%;
    font-size: clamp(32px, 15vw, 56px);
    line-height: 1;
  }

  .hero-copy,
  .section-description {
    font-size: 16px;
  }

  .section-card {
    min-height: 72vh;
  }

  .detail-card {
    min-height: auto;
  }
}
</style>

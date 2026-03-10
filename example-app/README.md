# example-app

iOS-only demo for `@mmsmart/capacitor-ios26-tabbar`.

The app renders one long scrollable page and uses the native tabbar from the plugin to jump between page sections. The package is linked locally via `file:..`.

## Run

```bash
cd example-app
npm install
npm run build
npm run cap:sync:ios
cd ios/App && pod install
npx cap open ios
```

`npm run cap:sync:ios` also restores the plugin pod path in `ios/App/Podfile`, because the local `file:..` dependency is installed as a symlink and Capacitor otherwise rewrites the path to the repository root.

In the browser, the page renders without the native tabbar and shows a short iOS-only note.

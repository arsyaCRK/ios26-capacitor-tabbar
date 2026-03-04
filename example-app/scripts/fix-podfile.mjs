import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const podfilePath = path.resolve(__dirname, '../ios/App/Podfile')
const expected = "pod 'MmsmartCapacitorIos26Tabbar', :path => '../../node_modules/@mmsmart/capacitor-ios26-tabbar'"
const generated = "pod 'MmsmartCapacitorIos26Tabbar', :path => '../../..'"

if (!fs.existsSync(podfilePath)) process.exit(0)

const contents = fs.readFileSync(podfilePath, 'utf8')

if (contents.includes(expected)) process.exit(0)
if (!contents.includes(generated)) process.exit(0)

fs.writeFileSync(podfilePath, contents.replace(generated, expected))

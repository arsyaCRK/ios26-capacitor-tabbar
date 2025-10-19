Pod::Spec.new do |s|
  s.name = 'MmsmartCapacitorIos26Tabbar'
  s.version = '1.1.6-prebuilt-rootpod'
  s.summary = 'Capacitor iOS TabBar with iOS26 glass, icon & title colors, context menu, runtime layout. (No icon animations)'
  s.license = { :type => 'MIT' }
  s.homepage = 'https://github.com/mmsmart/capacitor-ios26-tabbar'
  s.author = 'MimiSmart'
  s.source = { :git => 'https://github.com/mmsmart/capacitor-ios26-tabbar.git', :tag => s.version.to_s }
  s.source_files = 'ios/Plugin/*.{swift,h,m}'
  s.ios.deployment_target = '13.0'
  s.swift_version = '5.9'
  s.static_framework = true
  s.dependency 'Capacitor'
end

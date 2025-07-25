platform :ios, '15.0'
project 'Steez/Steez.xcodeproj'

target 'Steez' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Networking
  pod 'Alamofire', '~> 5.6'
  
  # Image Loading
  pod 'Kingfisher', '~> 7.0'
  
  # Local Storage
  pod 'RealmSwift', '~> 10.0'
  
  # UI Components
  pod 'SnapKit', '~> 5.6'
  
  # Analytics
  pod 'Firebase/Analytics'
  pod 'Firebase/Crashlytics'
  pod 'GoogleSignIn', '~> 7.0'
  # OAuth / Google Sign-In dependencies
  pod 'AppAuth', '~> 1.7'
  pod 'GTMAppAuth', '~> 4.1'
end

target 'SteezShareExtension' do
  use_frameworks!
  # Only include extension-safe dependencies
  pod 'Alamofire', '~> 5.6'
  pod 'Kingfisher', '~> 7.0'
  pod 'RealmSwift', '~> 10.0'
  pod 'SnapKit', '~> 5.6'
  # Exclude: AppAuth, GTMAppAuth, GoogleSignIn, Firebase (not App Extension safe)
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      # Enable App Extension API restrictions for share extension pods
      if target.name.include?('SteezShareExtension')
        config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
      end
    end
  end
end 
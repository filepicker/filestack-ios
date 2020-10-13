Pod::Spec.new do |spec|
  spec.name         = 'Filestack'
  spec.version      = File.read('./VERSION')
  spec.license      = { :type => 'Apache License, Version 2.0"', :file => "LICENSE" }
  spec.homepage     = 'https://github.com/filestack/filestack-ios'
  spec.authors      = { 'Filestack' => 'ios@filestack.com' }
  spec.summary      = 'Official iOS SDK for Filestack.'
  spec.source       = { :git => 'https://github.com/filestack/filestack-ios.git', :tag => spec.version }

  spec.ios.deployment_target  = '11.0'

  spec.source_files = 'Sources/Filestack/**/*.{h,swift}'
  spec.resources = ["Sources/Filestack/UI/Storyboards/*.storyboard", "Sources/Filestack/Resources/*.xcassets"]
  spec.public_header_files = 'Sources/**/*.h'

  spec.swift_versions = [4.2, 5.2]

  spec.dependency 'Alamofire', '~> 4.9'
  spec.dependency 'FilestackSDK', '~> 2.4'
  spec.dependency 'Zip', '~> 2.1'
end

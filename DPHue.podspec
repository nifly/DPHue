Pod::Spec.new do |s|
  s.name         = "DPHue"
  s.version      = "0.0.2"
  s.summary      = "Library for interacting with Philips Hue lighting systems."
  s.homepage     = "https://github.com/J-Swift/DPHue"
  s.license      = "public domain"
  s.authors      = {
    "Dan Parsons" => "dparsons@nyip.net",
    "Jimmy Reichley" => "jimmyqpublik@gmail.com"
  }
  s.source       = { :git => "https://github.com/J-Swift/DPHue.git", :tag => "v#{s.version}" }
  s.source_files = 'DPHue/*.{h,m}'
  s.requires_arc = true
  s.dependency 'CocoaAsyncSocket', '~> 7.4.1'
# JPR TODO: change to 7.0
  s.ios.deployment_target = '5.0'
  s.osx.deployment_target = '10.6'
end

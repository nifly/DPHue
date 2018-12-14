Pod::Spec.new do |s|
  s.name         = "DPHue"
  s.version      = "1.1.5"
  s.summary      = "Library for interacting with Philips Hue lighting systems."
  s.homepage     = "https://github.com/J-Swift/DPHue"
  s.license      = "public domain"
  s.authors      = {
    "Dan Parsons" => "dparsons@nyip.net",
    "Jimmy Reichley" => "jimmyqpublik@gmail.com"
  }
  s.source       = { :git => "https://github.com/Nifly/DPHue.git", :tag => "v#{s.version}" }
  s.source_files = 'DPHue/*.{h,m}'
  s.requires_arc = true
  s.dependency 'CocoaAsyncSocket', '~> 7.6.3'
  s.ios.deployment_target  = '7.0'
  s.osx.deployment_target  = '10.7'
  s.tvos.deployment_target = '9.0'
end

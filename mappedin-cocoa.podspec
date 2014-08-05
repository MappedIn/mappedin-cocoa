Pod::Spec.new do |s|

  s.name         = "mappedin-cocoa"
  s.version      = "0.7.1"
  s.summary      = "Cocoa bindings for the MappedIn API"

  s.homepage     = "https://github.com/MappedIn/mappedin-cocoa"

  s.license      = { :type => 'MIT', :file => 'LICENSE' }

  s.author       = { "MappedIn" => "support@mappedin.com" }

  s.platform     = :ios, '6.0'

  s.source       = { :git => "https://github.com/MappedIn/mappedin-cocoa.git", :tag => "v#{s.version}" }

  s.source_files = 'MappedInCocoa/Classes/**/*.{h,m}'

  s.requires_arc = true

  s.dependency   'AFNetworking', '~> 1.0'
  
  s.prefix_header_contents = <<-EOS
#ifdef __OBJC__
  #import <Security/Security.h>
  #if __IPHONE_OS_VERSION_MIN_REQUIRED
    #import <SystemConfiguration/SystemConfiguration.h>
    #import <MobileCoreServices/MobileCoreServices.h>
  #else
    #import <SystemConfiguration/SystemConfiguration.h>
    #import <CoreServices/CoreServices.h>
  #endif
#endif /* __OBJC__*/
EOS

end

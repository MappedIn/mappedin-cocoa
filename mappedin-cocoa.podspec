Pod::Spec.new do |s|

  s.name         = "mappedin-cocoa"
  s.version      = "0.0.1"
  s.summary      = "Cocoa bindings for the MappedIn API"

  s.homepage     = "https://github.com/MappedIn/mappedin-cocoa"

  s.license      = { :type => 'MIT', :file => 'LICENSE' }

  s.author       = { "MappedIn" => "support@mappedin.com" }

  s.platform     = :ios, '6.0'

  s.source       = { :git => "https://github.com/MappedIn/mappedin-cocoa.git", :commit => "88845601689389b262461b58dc90105f1cebc0e4" }

  s.source_files = 'MappedInCocoa/Classes/**/*.{h,m}'

  s.requires_arc = true

  s.dependency   'AFNetworking', '~> 2.0'

end

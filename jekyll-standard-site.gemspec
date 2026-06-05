require_relative "lib/jekyll-standard-site/version"

Gem::Specification.new do |spec|
  spec.name          = "jekyll-standard-site"
  spec.version       = Jekyll::StandardSite::VERSION
  spec.authors       = ["Andrew Nesbitt"]
  spec.email         = ["andrewnez@gmail.com"]

  spec.summary       = "Emit standard.site verification artifacts from a Jekyll site"
  spec.description   = "Generates the .well-known/site.standard.publication endpoint and provides a Liquid tag that emits site.standard.publication and site.standard.document link tags for AT Protocol verification."
  spec.homepage      = "https://github.com/andrew/jekyll-standard-site"
  spec.license       = "MIT"

  spec.metadata["source_code_uri"] = spec.homepage

  spec.files         = Dir["lib/**/*"]
  spec.extra_rdoc_files = Dir["README.md", "LICENSE.txt"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.7.0"

  spec.add_dependency "jekyll", ">= 3.7", "< 5.0"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest", "~> 5.0"
end

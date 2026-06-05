require "rake"
require "jekyll"
require_relative "../jekyll-standard-site"
require_relative "publisher"

namespace :standard_site do
  desc "Create site.standard.document records for posts missing at_uri and patch front matter"
  task :publish do
    handle = ENV["BSKY_HANDLE"] or abort("BSKY_HANDLE is not set")
    password = ENV["BSKY_APP_PASSWORD"] or abort("BSKY_APP_PASSWORD is not set")
    pds = ENV["BSKY_PDS"] || Jekyll::StandardSite::Publisher::DEFAULT_PDS

    site = Jekyll::Site.new(Jekyll.configuration({}))
    site.read

    publisher = Jekyll::StandardSite::Publisher.new(
      site:     site,
      handle:   handle,
      password: password,
      pds:      pds
    )

    published = publisher.publish_all
    if published.empty?
      puts "Standard.site: no posts to publish"
    else
      puts "Standard.site: published #{published.size} document(s)"
    end
  end
end

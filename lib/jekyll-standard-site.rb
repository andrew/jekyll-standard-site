require "jekyll"
require_relative "jekyll-standard-site/version"

module Jekyll
  module StandardSite
    AT_URI_PATTERN = %r{\Aat://did:[a-z]+:[a-zA-Z0-9._:%-]+/[a-zA-Z0-9.]+/[a-zA-Z0-9]+\z}.freeze

    def self.config(site)
      site.config["standard_site"] || {}
    end

    def self.publication_uri(site)
      config(site)["publication"]
    end

    class WellKnownGenerator < Jekyll::Generator
      safe true
      priority :low

      def generate(site)
        uri = StandardSite.publication_uri(site)
        return unless uri

        unless uri =~ StandardSite::AT_URI_PATTERN
          Jekyll.logger.warn "Standard.site:", "publication is not a valid AT-URI: #{uri}"
          return
        end

        path = StandardSite.config(site)["publication_path"]
        dir = ".well-known"
        name = "site.standard.publication"
        if path && !path.empty?
          dir = File.join(".well-known", "site.standard.publication", path.sub(%r{\A/}, ""))
          name = File.basename(dir)
          dir = File.dirname(dir)
        end

        file = Jekyll::PageWithoutAFile.new(site, site.source, dir, name)
        file.content = uri
        file.data["layout"] = nil
        file.data["sitemap"] = false
        site.pages << file
      end
    end

    class LinksTag < Liquid::Tag
      def render(context)
        site = context.registers[:site]
        page = context.registers[:page] || {}

        tags = []

        if (pub = StandardSite.publication_uri(site))
          tags << %(<link rel="site.standard.publication" href="#{pub}">)
        end

        doc = page["at_uri"]
        if doc
          if doc =~ StandardSite::AT_URI_PATTERN
            tags << %(<link rel="site.standard.document" href="#{doc}">)
          else
            Jekyll.logger.warn "Standard.site:", "at_uri on #{page["path"]} is not a valid AT-URI: #{doc}"
          end
        end

        tags.join("\n")
      end
    end
  end
end

Liquid::Template.register_tag("standard_site_links", Jekyll::StandardSite::LinksTag)

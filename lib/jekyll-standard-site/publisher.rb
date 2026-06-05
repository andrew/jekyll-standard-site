require "net/http"
require "json"
require "uri"
require "yaml"

module Jekyll
  module StandardSite
    class PublisherError < StandardError; end

    class HttpClient
      def post_json(url, body, headers = {})
        uri = URI(url)
        req = Net::HTTP::Post.new(uri)
        req["Content-Type"] = "application/json"
        headers.each { |k, v| req[k] = v }
        req.body = JSON.dump(body)

        res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
          http.request(req)
        end

        parsed = res.body && !res.body.empty? ? JSON.parse(res.body) : {}
        [res.code.to_i, parsed]
      end
    end

    class Publisher
      DEFAULT_PDS = "https://bsky.social".freeze

      def initialize(site:, handle:, password:, pds: DEFAULT_PDS, http: HttpClient.new, logger: Jekyll.logger)
        @site = site
        @handle = handle
        @password = password
        @pds = pds.sub(%r{/\z}, "")
        @http = http
        @logger = logger
      end

      def publish_all
        publication = StandardSite.publication_uri(@site)
        raise PublisherError, "standard_site.publication is not set in _config.yml" unless publication

        session = login
        published = []

        unpublished_posts.each do |post|
          uri = create_document_record(session, publication, post)
          patch_front_matter(post.path, uri)
          @logger.info "Standard.site:", "published #{post.relative_path} -> #{uri}"
          published << [post.relative_path, uri]
        end

        published
      end

      def unpublished_posts
        @site.read if @site.posts.docs.empty?
        @site.posts.docs.reject { |p| p.data["at_uri"] }
      end

      def login
        code, body = @http.post_json(
          "#{@pds}/xrpc/com.atproto.server.createSession",
          { "identifier" => @handle, "password" => @password }
        )
        raise PublisherError, "login failed (#{code}): #{body["message"] || body}" unless code == 200
        body
      end

      def create_document_record(session, publication, post)
        record = build_record(publication, post)
        code, body = @http.post_json(
          "#{@pds}/xrpc/com.atproto.repo.createRecord",
          {
            "repo" => session["did"],
            "collection" => "site.standard.document",
            "record" => record
          },
          "Authorization" => "Bearer #{session["accessJwt"]}"
        )
        raise PublisherError, "createRecord failed for #{post.relative_path} (#{code}): #{body["message"] || body}" unless code == 200
        body["uri"]
      end

      def build_record(publication, post)
        data = post.data
        record = {
          "$type" => "site.standard.document",
          "site" => publication,
          "title" => data["title"].to_s,
          "publishedAt" => normalize_time(post.date)
        }
        record["path"] = post.url if post.url
        record["description"] = data["description"] if data["description"]
        record["tags"] = Array(data["tags"]) if data["tags"] && !Array(data["tags"]).empty?
        record["updatedAt"] = normalize_time(data["updated"]) if data["updated"]
        record
      end

      def normalize_time(value)
        case value
        when Time then value.utc.strftime("%Y-%m-%dT%H:%M:%S.000Z")
        when String then value
        else raise PublisherError, "unrecognised time value: #{value.inspect}"
        end
      end

      def patch_front_matter(path, at_uri)
        content = File.read(path)
        unless content.start_with?("---\n") || content.start_with?("---\r\n")
          raise PublisherError, "no front matter in #{path}"
        end

        patched = content.sub(/\n---\r?\n/, %(\nat_uri: "#{at_uri}"\n---\n))
        if patched == content
          raise PublisherError, "could not locate closing front-matter delimiter in #{path}"
        end

        File.write(path, patched)
      end
    end
  end
end

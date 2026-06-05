require "test_helper"
require "jekyll-standard-site/publisher"

class FakeHttp
  attr_reader :calls

  def initialize(responses)
    @responses = responses
    @calls = []
  end

  def post_json(url, body, headers = {})
    @calls << { url: url, body: body, headers: headers }
    res = @responses.shift
    raise "no canned response for #{url}" unless res
    res
  end
end

class PublisherTest < Minitest::Test
  include JekyllTestHelper

  PUB_URI = "at://did:plc:abc123xyz/site.standard.publication/3lwafzkjqm25s".freeze
  DOC_URI = "at://did:plc:abc123xyz/site.standard.document/3mek5jhkri72r".freeze

  def teardown
    cleanup_site
  end

  def site_with_post(at_uri: nil)
    site = create_site("standard_site" => { "publication" => PUB_URI })
    create_post("2026-04-01-hello.md", title: "Hello world", at_uri: at_uri, content: "Body text")
    site.read
    site
  end

  def session_response
    [200, { "did" => "did:plc:abc123xyz", "accessJwt" => "jwt-token" }]
  end

  def test_publishes_posts_without_at_uri
    site = site_with_post
    http = FakeHttp.new([
      session_response,
      [200, { "uri" => DOC_URI, "cid" => "bafycid" }]
    ])

    pub = Jekyll::StandardSite::Publisher.new(
      site: site, handle: "alice.bsky", password: "pw", http: http
    )

    result = pub.publish_all
    assert_equal 1, result.size
    assert_equal DOC_URI, result.first.last

    assert_equal 2, http.calls.size
    login = http.calls[0]
    assert_match %r{createSession\z}, login[:url]
    assert_equal "alice.bsky", login[:body]["identifier"]

    record_call = http.calls[1]
    assert_match %r{createRecord\z}, record_call[:url]
    assert_equal "Bearer jwt-token", record_call[:headers]["Authorization"]
    record = record_call[:body]["record"]
    assert_equal "site.standard.document", record["$type"]
    assert_equal PUB_URI, record["site"]
    assert_equal "Hello world", record["title"]
    assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.000Z\z/, record["publishedAt"])
  end

  def test_skips_posts_with_at_uri
    site = site_with_post(at_uri: DOC_URI)
    http = FakeHttp.new([session_response])

    pub = Jekyll::StandardSite::Publisher.new(
      site: site, handle: "alice.bsky", password: "pw", http: http
    )

    result = pub.publish_all
    assert_empty result
    assert_equal 1, http.calls.size # only login
  end

  def test_patches_front_matter_with_at_uri
    site = site_with_post
    http = FakeHttp.new([
      session_response,
      [200, { "uri" => DOC_URI, "cid" => "bafycid" }]
    ])

    pub = Jekyll::StandardSite::Publisher.new(
      site: site, handle: "alice.bsky", password: "pw", http: http
    )
    pub.publish_all

    path = File.join(@source_dir, "_posts", "2026-04-01-hello.md")
    content = File.read(path)
    assert_match(/at_uri: "#{Regexp.escape(DOC_URI)}"/, content)
    assert content.start_with?("---\n")
    assert_includes content, "Body text"
  end

  def test_raises_when_publication_missing
    site = create_site
    create_post("2026-04-01-x.md", title: "X")
    site.read
    http = FakeHttp.new([])

    pub = Jekyll::StandardSite::Publisher.new(
      site: site, handle: "alice.bsky", password: "pw", http: http
    )

    err = assert_raises(Jekyll::StandardSite::PublisherError) { pub.publish_all }
    assert_match(/publication is not set/, err.message)
  end

  def test_raises_on_login_failure
    site = site_with_post
    http = FakeHttp.new([[401, { "message" => "Invalid credentials" }]])

    pub = Jekyll::StandardSite::Publisher.new(
      site: site, handle: "alice.bsky", password: "bad", http: http
    )

    err = assert_raises(Jekyll::StandardSite::PublisherError) { pub.publish_all }
    assert_match(/login failed/, err.message)
    assert_match(/Invalid credentials/, err.message)
  end

  def test_raises_on_create_record_failure
    site = site_with_post
    http = FakeHttp.new([
      session_response,
      [400, { "message" => "InvalidRecord" }]
    ])

    pub = Jekyll::StandardSite::Publisher.new(
      site: site, handle: "alice.bsky", password: "pw", http: http
    )

    err = assert_raises(Jekyll::StandardSite::PublisherError) { pub.publish_all }
    assert_match(/createRecord failed/, err.message)
  end

  def test_includes_tags_and_description
    site = create_site("standard_site" => { "publication" => PUB_URI })
    create_post("2026-04-02-tagged.md",
                title: "Tagged",
                description: "A tagged post",
                tags: ["ruby", "atproto"])
    site.read

    http = FakeHttp.new([
      session_response,
      [200, { "uri" => DOC_URI, "cid" => "x" }]
    ])

    pub = Jekyll::StandardSite::Publisher.new(
      site: site, handle: "alice.bsky", password: "pw", http: http
    )
    pub.publish_all

    record = http.calls[1][:body]["record"]
    assert_equal "A tagged post", record["description"]
    assert_equal ["ruby", "atproto"], record["tags"]
  end
end

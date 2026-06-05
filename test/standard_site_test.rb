require "test_helper"

class StandardSiteTest < Minitest::Test
  include JekyllTestHelper

  PUB_URI = "at://did:plc:abc123xyz/site.standard.publication/3lwafzkjqm25s".freeze
  DOC_URI = "at://did:plc:abc123xyz/site.standard.document/3mek5jhkri72r".freeze

  def teardown
    cleanup_site
  end

  def test_generates_well_known_file_with_publication_uri
    site = create_site("standard_site" => { "publication" => PUB_URI })
    site.process

    body = read_dest(".well-known", "site.standard.publication")
    assert_equal PUB_URI, body.strip
  end

  def test_skips_well_known_when_unconfigured
    site = create_site
    site.process

    assert_nil read_dest(".well-known", "site.standard.publication")
  end

  def test_skips_well_known_when_uri_invalid
    site = create_site("standard_site" => { "publication" => "https://not-an-at-uri" })
    site.process

    assert_nil read_dest(".well-known", "site.standard.publication")
  end

  def test_non_root_publication_path
    site = create_site("standard_site" => {
      "publication"      => PUB_URI,
      "publication_path" => "/section/blog"
    })
    site.process

    body = read_dest(".well-known", "site.standard.publication", "section", "blog")
    assert_equal PUB_URI, body.strip
  end

  def test_links_tag_emits_publication_hint
    site = create_site("standard_site" => { "publication" => PUB_URI })
    create_post("2026-01-01-hello.md", title: "Hello")
    site.process

    html = read_dest("2026", "01", "01", "hello", "index.html")
    assert_includes html, %(<link rel="site.standard.publication" href="#{PUB_URI}">)
  end

  def test_links_tag_emits_document_link_when_at_uri_present
    site = create_site("standard_site" => { "publication" => PUB_URI })
    create_post("2026-01-02-doc.md", title: "Doc", at_uri: DOC_URI)
    site.process

    html = read_dest("2026", "01", "02", "doc", "index.html")
    assert_includes html, %(<link rel="site.standard.document" href="#{DOC_URI}">)
  end

  def test_links_tag_omits_document_link_when_no_at_uri
    site = create_site("standard_site" => { "publication" => PUB_URI })
    create_post("2026-01-03-bare.md", title: "Bare")
    site.process

    html = read_dest("2026", "01", "03", "bare", "index.html")
    refute_includes html, "site.standard.document"
  end

  def test_links_tag_emits_nothing_when_unconfigured
    site = create_site
    create_post("2026-01-04-none.md", title: "None")
    site.process

    html = read_dest("2026", "01", "04", "none", "index.html")
    refute_includes html, "site.standard.publication"
    refute_includes html, "site.standard.document"
  end

  def test_links_tag_skips_invalid_document_uri
    site = create_site("standard_site" => { "publication" => PUB_URI })
    create_post("2026-01-05-bad.md", title: "Bad", at_uri: "nope")
    site.process

    html = read_dest("2026", "01", "05", "bad", "index.html")
    refute_includes html, "site.standard.document"
  end
end

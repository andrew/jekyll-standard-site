# jekyll-standard-site

A Jekyll plugin that emits the verification artifacts required by [standard.site](https://standard.site), the AT Protocol lexicons for long-form publishing.

The plugin does not create AT Protocol records. Those live on your PDS and are created separately (via the standard.site dashboard, `goat`, `@atproto/api`, etc.). Once the records exist, this plugin handles the static-site side: a `.well-known` endpoint for your publication and `<link>` tags on each post that point at the corresponding document record.

## Installation

Add to your Gemfile:

```ruby
group :jekyll_plugins do
  gem "jekyll-standard-site"
end
```

And to `_config.yml`:

```yaml
plugins:
  - jekyll-standard-site

standard_site:
  publication: "at://did:plc:abc123/site.standard.publication/3lwafzkjqm25s"
```

## Usage

### Publication verification

The plugin writes the publication AT-URI to `/.well-known/site.standard.publication`. No further setup needed.

If the publication is not at the domain root, set `publication_path`:

```yaml
standard_site:
  publication: "at://did:plc:abc123/site.standard.publication/3lwafzkjqm25s"
  publication_path: "/blog"
```

This writes to `/.well-known/site.standard.publication/blog` per the [verification spec](https://standard.site/docs/verification).

### Document verification

Add the document's AT-URI to each post's front matter:

```yaml
---
title: My First Post
at_uri: "at://did:plc:abc123/site.standard.document/3mek5jhkri72r"
---
```

Then drop the Liquid tag into your `<head>` layout:

```liquid
{% standard_site_links %}
```

This emits a `site.standard.publication` discovery hint on every page and a `site.standard.document` link tag on any page whose front matter includes `at_uri`.

## License

MIT

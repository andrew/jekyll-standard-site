# jekyll-standard-site

A Jekyll plugin that emits the verification artifacts required by [standard.site](https://standard.site), the AT Protocol lexicons for long-form publishing.

It does two things:

1. **At build time**, emits the `.well-known` endpoint and the `<link>` tags that prove your site owns its publication and document records.
2. **At publish time**, optionally creates `site.standard.document` records on your PDS and writes the returned AT-URIs back into each post's front matter, so the next build emits the document verification link.

## Installation

```ruby
group :jekyll_plugins do
  gem "jekyll-standard-site"
end
```

In `_config.yml`:

```yaml
plugins:
  - jekyll-standard-site

standard_site:
  publication: "at://did:plc:abc123/site.standard.publication/3lwafzkjqm25s"
```

## Bootstrap: create the publication record

This gem does **not** create the publication record. That's a one-time step you do out-of-band, then paste the resulting AT-URI into `_config.yml`.

Pick whichever flow you prefer:

- The [standard.site](https://standard.site) dashboard
- [`goat`](https://github.com/bluesky-social/indigo/tree/main/cmd/goat) — `goat record create --collection site.standard.publication --record '{"url":"https://example.com","name":"Example"}'`
- [`sequoia-cli`](https://sequoia.pub)
- A direct `com.atproto.repo.createRecord` call

Once the record exists, set `standard_site.publication` and the well-known endpoint plus the publication discovery hint start working immediately on the next build.

## Build-time behaviour

### `.well-known/site.standard.publication`

Written automatically from `standard_site.publication`. If your publication is not at the domain root, set `publication_path`:

```yaml
standard_site:
  publication: "at://did:plc:abc123/site.standard.publication/3lwafzkjqm25s"
  publication_path: "/blog"
```

This writes to `/.well-known/site.standard.publication/blog`.

### Verification link tags

Drop the Liquid tag into your `<head>` layout:

```liquid
{% standard_site_links %}
```

It emits a `site.standard.publication` discovery hint on every page, and a `site.standard.document` link tag on any page whose front matter includes `at_uri`.

## Publishing documents

To verify individual posts and have them discoverable via standard.site readers, each post needs a `site.standard.document` record on your PDS, plus its AT-URI in the post's front matter as `at_uri`.

This gem ships a Rake task that handles both. Add to your `Rakefile`:

```ruby
require "jekyll-standard-site/tasks"
```

Then:

```
BSKY_HANDLE=you.bsky.social BSKY_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx bundle exec rake standard_site:publish
```

The task:

1. Logs in via `com.atproto.server.createSession` using the credentials in env vars.
2. Reads `_posts` and finds posts whose front matter has no `at_uri`.
3. For each, calls `com.atproto.repo.createRecord` with a `site.standard.document` payload built from the post's `title`, `description`, `tags`, `date`, and URL.
4. Patches the returned AT-URI back into the post file as `at_uri: "..."`.

It's idempotent. Re-running skips any post that already has `at_uri`.

Env vars:

- `BSKY_HANDLE` — your handle (e.g. `you.bsky.social`).
- `BSKY_APP_PASSWORD` — generate at <https://bsky.app/settings/app-passwords>. Use a dedicated one.
- `BSKY_PDS` — defaults to `https://bsky.social`. Override if you self-host.

### GitHub Actions

A workflow that publishes documents whenever new posts land on `master`:

```yaml
name: Publish documents

on:
  push:
    branches: ["master"]
    paths: ["_posts/**"]

permissions: {}

concurrency:
  group: standard-site-publish
  cancel-in-progress: false

jobs:
  publish:
    if: github.actor != 'github-actions[bot]'
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v6
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - run: bundle exec rake standard_site:publish
        env:
          BSKY_HANDLE: ${{ secrets.BSKY_HANDLE }}
          BSKY_APP_PASSWORD: ${{ secrets.BSKY_APP_PASSWORD }}
      - name: Commit patched front matter
        run: |
          if [[ -n "$(git status --porcelain _posts)" ]]; then
            git config user.name "github-actions[bot]"
            git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
            git add _posts
            git commit -m "Add at_uri to new posts [skip ci]"
            git push
          fi
```

The `[skip ci]` plus the `github.actor` guard stop the bot's own commits from re-triggering the workflow.

## License

MIT

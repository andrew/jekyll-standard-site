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
- [`goat`](https://github.com/bluesky-social/goat). Write the record body to a JSON file (including `$type: site.standard.publication`), then `goat account login` and `goat record create --no-validate publication.json`. `--no-validate` is required: most PDSs don't know the `site.standard.*` lexicons yet, and without it the PDS rejects the record before persisting it.
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

A workflow that publishes documents whenever new posts land on `master`, with a `workflow_dispatch` trigger for one-off backfill runs:

```yaml
name: Publish documents

on:
  push:
    branches: ["master"]
    paths: ["_posts/**"]
  workflow_dispatch:

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
        with:
          persist-credentials: false
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - run: bundle exec rake standard_site:publish
        env:
          BSKY_HANDLE: ${{ secrets.BSKY_HANDLE }}
          BSKY_APP_PASSWORD: ${{ secrets.BSKY_APP_PASSWORD }}
      - name: Commit patched front matter
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          if [[ -n "$(git status --porcelain _posts)" ]]; then
            git config user.name "github-actions[bot]"
            git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
            git add _posts
            git commit -m "Add at_uri to new posts [skip ci]"
            git push "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" "HEAD:${GITHUB_REF_NAME}"
          fi
```

`persist-credentials: false` on checkout plus the explicit token in the push URL is what zizmor expects: the token only lives in this one step rather than in `.git/config` for the whole job. The `[skip ci]` plus the `github.actor` guard stop the bot's own commits from re-triggering the workflow.

## Known issues

### GitHub Pages strips `.well-known/`

If you deploy with `actions/upload-pages-artifact`, it hard-codes `--exclude=".[^/]*"` when building the tarball, which silently drops `.well-known/site.standard.publication` from the deployed site and breaks publication verification. There is no flag to disable the exclusion.

The fix is to build the tar yourself and upload it as the `github-pages` artifact directly. Replace the upload step in your Pages deploy workflow with:

```yaml
- name: Bundle artifact
  run: |
    tar \
      --dereference --hard-dereference \
      --directory _site \
      -cvf "$RUNNER_TEMP/artifact.tar" \
      --exclude=.git --exclude=.github \
      .

- name: Upload artifact
  uses: actions/upload-artifact@v4
  with:
    name: github-pages
    path: ${{ runner.temp }}/artifact.tar
    retention-days: 1
    if-no-files-found: error
```

`actions/deploy-pages` consumes the `github-pages` artifact unchanged, so the rest of your pipeline stays the same.

### `path` must match your post URL

The `path` field on each document record is derived from `post.url`, which Jekyll computes from your `permalink` config and the post filename. If `path` doesn't match the canonical URL the post is actually served at, document verification fails. Don't change your permalink scheme after publishing without re-creating the records.

## License

MIT

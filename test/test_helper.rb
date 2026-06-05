$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "jekyll"
require "jekyll-standard-site"
require "fileutils"
require "tmpdir"

module JekyllTestHelper
  def create_site(config = {})
    @tmp_dir = Dir.mktmpdir("jekyll-standard-site-test")
    @source_dir = File.join(@tmp_dir, "source")
    @dest_dir = File.join(@tmp_dir, "_site")

    FileUtils.mkdir_p(@source_dir)
    FileUtils.mkdir_p(File.join(@source_dir, "_posts"))
    FileUtils.mkdir_p(File.join(@source_dir, "_layouts"))

    File.write(File.join(@source_dir, "_layouts", "post.html"), <<~LAYOUT)
      <!doctype html>
      <html><head>{% standard_site_links %}</head><body>{{ content }}</body></html>
    LAYOUT

    default_config = {
      "source"      => @source_dir,
      "destination" => @dest_dir,
      "title"       => "Test Site",
      "permalink"   => "pretty"
    }

    Jekyll::Site.new(Jekyll.configuration(default_config.merge(config)))
  end

  def create_post(filename, title: "Post", at_uri: nil, content: "Body")
    posts_dir = File.join(@source_dir, "_posts")
    front_matter = ["layout: post", %(title: "#{title}")]
    front_matter << %(at_uri: "#{at_uri}") if at_uri
    File.write(File.join(posts_dir, filename), <<~POST)
      ---
      #{front_matter.join("\n")}
      ---
      #{content}
    POST
  end

  def read_dest(*parts)
    path = File.join(@dest_dir, *parts)
    File.exist?(path) ? File.read(path) : nil
  end

  def cleanup_site
    FileUtils.rm_rf(@tmp_dir) if @tmp_dir && File.exist?(@tmp_dir)
  end
end

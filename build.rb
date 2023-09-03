require "bundler/inline"

gemfile do
  source "https://rubygems.org"

  gem "redcarpet", "~> 3.6"
  gem "rouge", "~> 4.1"
end

require "erb"

class Template
  def initialize(file_path)
    @template = ::ERB.new(::File.read(file_path))
  end

  def render(locals, save_to:)
    binding = ::Object.new.send(:binding).tap do |binding|
      locals.each { |key, value| binding.local_variable_set(key, value) }
    end

    ::File.write(save_to, @template.result(binding))
  end
end

module Post
  Data = ::Struct.new(
    :id,
    :metadata,
    :html_body,
    keyword_init: true
  )

  class Metadata
    Parse = ->(lines) { ::Hash[lines.map { |line| line[2..].split(":").map(&:strip) }] }

    def initialize(attributes)
      @attributes = attributes
    end

    def title            = @attributes["title"]
    def publication_date = @attributes["publication_date"]
    def summary          = @attributes["summary"]
    def published?       = !!publication_date
  end

  ParsePost = ->(markdown_renderer, file_path) do
    id = ::File.basename(file_path).gsub(".md", "")

    lines = ::File.read(file_path).split("\n")
    metadata_lines = lines.take_while { |line| line.start_with?("--") }
    markdown_content_lines = lines.drop(metadata_lines.size + 1)

    metadata = Metadata.new(Metadata::Parse[metadata_lines])
    markdown_body = markdown_content_lines.join("\n")
    html_body = markdown_renderer.render(markdown_body)

    Data.new(id:, metadata:, html_body:)
  end

  MARKDOWN_RENDERER = ::Redcarpet::Markdown.new(Redcarpet::Render::HTML, fenced_code_blocks: true)

  RECORDS = ::Dir.glob("posts/*.md").map(&ParsePost.curry[MARKDOWN_RENDERER])
    .filter { |post| post.metadata.published? }
    .sort_by { |post| post.metadata.publication_date }
    .reverse

  JOURNAL = ::Dir.glob("posts/journal/*.md").map(&ParsePost.curry[MARKDOWN_RENDERER])
end

# ======== main ========

puts "#{Time.now}: Building..."

Template.new("pages/index.html.erb").tap do |index_template|
  index_template.render({ posts: Post::RECORDS, journal: Post::JOURNAL }, save_to: "_dist/index.html")
end

Template.new("pages/post.html.erb").tap do |post_template|
  Post::RECORDS.each do |post|
    post_template.render({ post: }, save_to: "_dist/#{post.id}.html")
  end

  Post::JOURNAL.each do |journal_post|
    post_template.render({ post: journal_post }, save_to: "_dist/#{journal_post.id}.html")
  end
end

puts "#{Time.now}: Built!"

require "nokogiri"

module Opengraph::Document
  extend self

  def opengraph_attributes(html)
    document = Nokogiri::HTML(html)

    opengraph_tags = document.xpath("//*/meta[starts-with(@property, \"og:\") or starts-with(@name, \"og:\")]").map do |tag|
      key = tag.key?("property") ? "property" : "name"
      [ tag[key].gsub("og:", "").to_sym, sanitize_content(document, tag["content"]) ] if tag["content"].present?
    end

    Hash[opengraph_tags.compact].slice(*Opengraph::Metadata::ATTRIBUTES)
  end

  private
    def sanitize_content(document, content)
      document.meta_encoding ? content : content.encode("UTF-8", "binary", invalid: :replace, undef: :replace, replace: "")
    end
end

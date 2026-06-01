module ContentFilters::RemoveSoloUnfurledLinkText
  extend self

  TWITTER_DOMAINS = %w[ x.com twitter.com ]
  TWITTER_DOMAIN_MAPPING = { "x.com" => "twitter.com" }

  def apply(content)
    return content unless applicable?(content)

    new_fragment = content.fragment.replace("div") { |node| node.tap { |n| n.inner_html = unfurled_links(content).first.to_s } }
    ActionText::Content.new(new_fragment, canonicalize: false)
  end

  def applicable?(content)
    normalize_tweet_url(solo_unfurled_url(content)) == normalize_tweet_url(content.to_plain_text)
  end

  private
    def solo_unfurled_url(content)
      links = unfurled_links(content)
      links.first["href"] if links.size == 1
    end

    def unfurled_links(content)
      content.fragment.find_all("action-text-attachment[@content-type='#{ActionText::Attachment::OpengraphEmbed::OPENGRAPH_EMBED_CONTENT_TYPE}']")
    end

    def normalize_tweet_url(url)
      return url unless twitter_url?(url)

      uri = URI.parse(url)

      uri.dup.tap do |u|
        u.host = TWITTER_DOMAIN_MAPPING[uri.host&.downcase] || uri.host
        u.query = nil
      end.to_s
    rescue URI::InvalidURIError
      url
    end

    def twitter_url?(url)
      url.present? && TWITTER_DOMAINS.any? { |domain| url.strip.include?(domain) }
    end
end

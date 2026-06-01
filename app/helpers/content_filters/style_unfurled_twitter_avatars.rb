module ContentFilters::StyleUnfurledTwitterAvatars
  extend self

  UNFURLED_TWITTER_AVATAR_CSS_CLASS = "cf-twitter-avatar"
  TWITTER_AVATAR_URL_PREFIX = "https://pbs.twimg.com/profile_images"

  def apply(content)
    return content unless applicable?(content)

    new_fragment = content.fragment.update do |source|
      div = source.at_css("div")
      div["class"] = UNFURLED_TWITTER_AVATAR_CSS_CLASS
    end
    ActionText::Content.new(new_fragment, canonicalize: false)
  end

  def applicable?(content)
    unfurled_twitter_avatars(content).present?
  end

  private
    def unfurled_twitter_avatars(content)
      content.fragment.find_all("#{opengraph_css_selector}[url*='#{TWITTER_AVATAR_URL_PREFIX}']")
    end

    def opengraph_css_selector
      "action-text-attachment[@content-type='#{ActionText::Attachment::OpengraphEmbed::OPENGRAPH_EMBED_CONTENT_TYPE}']"
    end
end

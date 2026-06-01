module ContentFilters
  TextMessagePresentationFilters = ActionText::Content::Filters.new(filters: [ RemoveSoloUnfurledLinkText, StyleUnfurledTwitterAvatars, SanitizeTags ])
end

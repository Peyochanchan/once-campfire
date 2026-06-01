ActionText::Content::Filters = Data.define(:filters) do
  def apply(content)
    filters.reduce(content) { |content, filter| filter.apply(content) }
  end
end

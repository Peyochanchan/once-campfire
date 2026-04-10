module Message::Searchable
  extend ActiveSupport::Concern

  TS_CONFIG = "french_unaccent"

  included do
    after_create_commit  :update_search_index
    after_update_commit  :update_search_index

    scope :search, ->(query) {
      where(
        "searchable @@ plainto_tsquery('#{TS_CONFIG}', unaccent(?)) OR searchable::text ILIKE '%' || unaccent(?) || '%'",
        query, query
      ).order(
        Arel.sql("ts_rank(searchable, plainto_tsquery('#{TS_CONFIG}', unaccent(#{connection.quote(query)}))) DESC")
      )
    }
  end

  private
    def update_search_index
      text = searchable_text
      update_column :searchable, self.class.connection.execute(
        self.class.sanitize_sql(["SELECT to_tsvector('#{TS_CONFIG}', ?) AS v", text])
      ).first["v"]
    end

    def searchable_text
      parts = [ body.to_plain_text.presence ]

      if attachment&.filename.present?
        filename = attachment.filename.to_s
        # Split CamelCase/acronyms and remove extension for better tokenization
        split_name = filename.sub(/\.\w+$/, "")
          .gsub(/([a-z])([A-Z])/, '\1 \2')
          .gsub(/([A-Z]+)([A-Z][a-z])/, '\1 \2')
          .gsub(/[_\-.]/, " ")
        parts << filename << split_name
      end

      parts.compact_blank.join(" ")
    end
end

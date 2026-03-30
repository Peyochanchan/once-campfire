module Message::Searchable
  extend ActiveSupport::Concern

  included do
    after_create_commit  :update_search_index
    after_update_commit  :update_search_index

    scope :search, ->(query) {
      where("searchable @@ plainto_tsquery('simple', ?)", query)
        .order(Arel.sql("ts_rank(searchable, plainto_tsquery('simple', #{connection.quote(query)})) DESC"))
    }
  end

  private
    def update_search_index
      update_column :searchable, self.class.connection.execute(
        self.class.sanitize_sql(["SELECT to_tsvector('simple', ?) AS v", plain_text_body])
      ).first["v"]
    end
end

class EnableUnaccentAndFrenchSearch < ActiveRecord::Migration[8.2]
  def up
    enable_extension "unaccent"
    enable_extension "pg_trgm"

    # Create a custom text search config: French stemming + unaccent
    execute <<~SQL
      CREATE TEXT SEARCH CONFIGURATION french_unaccent (COPY = french);
      ALTER TEXT SEARCH CONFIGURATION french_unaccent
        ALTER MAPPING FOR hword, hword_part, word WITH unaccent, french_stem;
    SQL

    # Reindex all existing messages with the new config
    execute <<~SQL
      UPDATE messages SET searchable = to_tsvector('french_unaccent', COALESCE(
        (SELECT body FROM action_text_rich_texts WHERE record_type = 'Message' AND record_id = messages.id AND name = 'body'),
        ''
      ));
    SQL
  end

  def down
    execute "DROP TEXT SEARCH CONFIGURATION IF EXISTS french_unaccent"
    disable_extension "pg_trgm"
    disable_extension "unaccent"
  end
end

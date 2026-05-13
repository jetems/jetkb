# frozen_string_literal: true

# Layer PG full-text search on top of the search_records_* shards.
#
# Each shard table gets a STORED generated column `search_vector` that
# concatenates account_key + title + content into a tsvector, plus a GIN
# index for fast `@@ to_tsquery(...)` lookups.
#
# Text search configuration is named "jetkb_search". Out of the box it is a
# clone of "simple" (whitespace tokenizer, no stemming). For Chinese-heavy
# corpora, follow docs/jetkb-postgresql-roadmap.md §5.3 to swap in zhparser
# or pg_jieba and rebuild this config — no schema migration needed, just:
#
#   ALTER TEXT SEARCH CONFIGURATION jetkb_search
#     ALTER MAPPING FOR ... WITH zhparser;
#   REINDEX INDEX search_records_<n>_search_gin;
class AddSearchVectorAndGin < ActiveRecord::Migration[8.2]
  SHARD_COUNT = 16

  def up
    # 1. Define the text-search configuration the app references.
    execute <<~SQL
      CREATE TEXT SEARCH CONFIGURATION jetkb_search ( COPY = simple );
    SQL

    # 2. For each shard, add a STORED tsvector + GIN index.
    SHARD_COUNT.times do |shard|
      table = "search_records_#{shard}"

      execute <<~SQL
        ALTER TABLE #{table}
          ADD COLUMN search_vector tsvector
          GENERATED ALWAYS AS (
            to_tsvector(
              'jetkb_search',
              coalesce(account_key, '') || ' ' ||
              coalesce(title, '')       || ' ' ||
              coalesce(content, '')
            )
          ) STORED;
      SQL

      execute <<~SQL
        CREATE INDEX #{table}_search_gin
          ON #{table}
          USING gin (search_vector);
      SQL
    end
  end

  def down
    SHARD_COUNT.times do |shard|
      table = "search_records_#{shard}"
      execute "DROP INDEX IF EXISTS #{table}_search_gin"
      execute "ALTER TABLE #{table} DROP COLUMN IF EXISTS search_vector"
    end

    execute "DROP TEXT SEARCH CONFIGURATION IF EXISTS jetkb_search"
  end
end

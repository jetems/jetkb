module Search::Record::PostgreSQL
  extend ActiveSupport::Concern

  SHARD_COUNT = 16

  included do
    self.abstract_class = true
    before_save :set_account_key, :stem_content

    # PG full-text search uses a STORED tsvector column (`search_vector`)
    # populated by the database from account_key/title/content and indexed
    # with GIN. The "simple" dictionary works for English + Chinese after a
    # tokenizer extension (zhparser or pg_jieba) is configured; see
    # docs/jetkb-postgresql-roadmap.md §5.3.
    scope :matching, ->(query, account_id) do
      # account_id may be a 36-char hyphenated UUID under PG; hyphens are NOT
      # operators in to_tsquery, so strip them to match the account_key tokens
      # written by set_account_key.
      account_token = "account#{account_id.to_s.delete('-')}"
      ts_query = "#{account_token} & (#{Search::Stemmer.stem(query).split(/\s+/).reject(&:empty?).join(" & ")})"
      where("search_vector @@ to_tsquery('jetkb_search', ?)", ts_query)
    end

    SHARD_CLASSES = SHARD_COUNT.times.map do |shard_id|
      Class.new(self) do
        self.table_name = "search_records_#{shard_id}"

        def self.name
          "Search::Record"
        end
      end
    end.freeze
  end

  class_methods do
    def shard_id_for_account(account_id)
      Zlib.crc32(account_id.to_s) % SHARD_COUNT
    end

    # We do all match-highlighting in Ruby (Search::Highlighter) using the
    # original Card#title / Card#description text, mirroring the Trilogy path.
    # ts_headline would highlight against the *stored* search-record title,
    # which is stemmed and lowercased by stem_content — that loses the
    # original case and also doesn't HTML-escape the source text, breaking
    # the upstream "preserves marks but escapes surrounding HTML" assertion.
    def search_fields(query)
      "#{connection.quote(query.terms)} AS query"
    end

    def for(account_id)
      SHARD_CLASSES[shard_id_for_account(account_id)]
    end
  end

  def card_title
    highlight(card.title, show: :full) if card_id
  end

  def card_description
    highlight(card.description.to_plain_text, show: :snippet) if card_id && !comment
  end

  def comment_body
    highlight(comment.body.to_plain_text, show: :snippet) if comment
  end

  private
    def stem_content
      self.title = Search::Stemmer.stem(title) if title_changed?
      self.content = Search::Stemmer.stem(content) if content_changed?
    end

    def set_account_key
      self.account_key = "account#{account_id.to_s.delete('-')}"
    end

    def highlight(text, show:)
      if text.present? && attribute?(:query)
        highlighter = Search::Highlighter.new(query)
        show == :snippet ? highlighter.snippet(text) : highlighter.highlight(text)
      else
        text
      end
    end
end

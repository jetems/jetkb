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

    def search_fields(query)
      open_mark = connection.quote(Search::Highlighter::OPENING_MARK)
      close_mark = connection.quote(Search::Highlighter::CLOSING_MARK)
      ts_q = connection.quote(Search::Stemmer.stem(query.terms).split(/\s+/).reject(&:empty?).join(" & "))

      # ts_headline returns the original text with <mark>...</mark> wraps.
      # We don't go through Ruby's Highlighter pipeline (no stemming needed
      # at render time) — PG returns ready-to-render HTML fragments.
      [ "ts_headline('jetkb_search', title, to_tsquery('jetkb_search', #{ts_q}), 'StartSel=' || #{open_mark} || ', StopSel=' || #{close_mark}) AS result_title",
        "ts_headline('jetkb_search', content, to_tsquery('jetkb_search', #{ts_q}), 'StartSel=' || #{open_mark} || ', StopSel=' || #{close_mark} || ', MaxFragments=2, MaxWords=20, MinWords=5') AS result_content",
        "#{connection.quote(query.terms)} AS query" ]
    end

    def for(account_id)
      SHARD_CLASSES[shard_id_for_account(account_id)]
    end
  end

  def card_title
    result_title || card&.title.then { |t| highlight(t, show: :full) }
  end

  def card_description
    if (text = (respond_to?(:result_content) && result_content)) && !comment
      text.html_safe
    elsif !comment
      highlight(card&.description&.to_plain_text, show: :snippet)
    end
  end

  def comment_body
    if (text = (respond_to?(:result_content) && result_content)) && comment
      text.html_safe
    elsif comment
      highlight(comment.body.to_plain_text, show: :snippet)
    end
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

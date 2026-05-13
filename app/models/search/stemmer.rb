module Search::Stemmer
  extend self

  STEMMER = Mittens::Stemmer.new

  # Unicode "Han" + CJK Symbols/Punctuation; treat each char as a token unit and
  # emit overlapping bigrams. Kanji-using languages (Chinese/Japanese kanji) share
  # this range. Hiragana/Katakana/Hangul are handled by the same bigram path
  # because they also lack reliable whitespace tokenization.
  CJK_CHAR = /\p{Han}|\p{Hiragana}|\p{Katakana}|\p{Hangul}/.freeze
  CJK_RUN  = /(?:#{CJK_CHAR.source})+/.freeze

  def stem(value)
    return value unless value.present?

    # Split into alternating CJK runs and non-CJK chunks. CJK runs go through
    # bigram tokenization; the rest goes through the original Snowball pipeline.
    tokens = []
    value.scan(/(#{CJK_RUN.source})|([^\s]+)|(\s+)/) do |cjk, word, _ws|
      if cjk
        tokens.concat(cjk_bigrams(cjk))
      elsif word
        # Strip remaining punctuation around the word, downcase, then stem.
        cleaned = word.gsub(/[^\p{L}\p{N}_]+/u, " ").split(/\s+/).reject(&:empty?)
        tokens.concat(cleaned.map { |w| STEMMER.stem(w.downcase) })
      end
    end
    tokens.join(" ")
  end

  private
    # "深圳公司" → ["深圳", "圳公", "公司"]. A single CJK char becomes a unigram.
    def cjk_bigrams(run)
      chars = run.chars
      return chars if chars.size == 1
      chars.each_cons(2).map(&:join)
    end
end

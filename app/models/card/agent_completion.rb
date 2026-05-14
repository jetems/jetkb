class Card::AgentCompletion < ApplicationRecord
  self.table_name = "card_agent_completions"

  RESULTS = %w[ succeeded failed cancelled needs_human ].freeze
  MAX_ARTIFACTS = 10

  class NotAssigned < StandardError; end

  belongs_to :card
  belongs_to :user
  belongs_to :comment, optional: true
  belongs_to :event,   optional: true

  validates :result, inclusion: { in: RESULTS }
  validate  :artifacts_within_limit

  def self.record!(card:, agent:, result:, summary:, outcome: nil, details_html: nil, artifacts: [], metrics: {}, idempotency_key: nil)
    raise NotAssigned, "agent #{agent.id} is not assigned to card #{card.id}" unless card.assigned_to?(agent)

    if idempotency_key.present?
      existing = where(card: card, user: agent, idempotency_key: idempotency_key).first
      return existing if existing
    end

    derived_outcome = outcome.presence || derive_outcome(result)

    transaction do
      comment = card.comments.create!(creator: agent, body: build_comment_body(result: result, summary: summary, details_html: details_html, artifacts: artifacts))
      apply_outcome!(card: card, outcome: derived_outcome, agent: agent)
      card.toggle_assignment(agent) if card.assigned_to?(agent)
      event = card.track_event(:agent_completed, creator: agent, result: result, summary: summary, outcome: derived_outcome, artifacts: artifacts, metrics: metrics)

      create!(
        card: card,
        user: agent,
        idempotency_key: idempotency_key,
        result: result,
        comment: comment,
        event: event,
        particulars: { summary: summary, outcome: derived_outcome, artifacts: artifacts, metrics: metrics }
      )
    end
  end

  private_class_method def self.derive_outcome(result)
    case result
    when "succeeded"             then "closed"
    when "cancelled"             then "not_now"
    when "failed", "needs_human" then "none"
    end
  end

  private_class_method def self.apply_outcome!(card:, outcome:, agent:)
    case outcome
    when "closed"  then card.close(user: agent)
    when "not_now" then card.postpone(user: agent)
    when "none", nil then nil
    when /\Atriaged:(?<column_id>.+)\z/
      column = card.board.columns.find(Regexp.last_match[:column_id])
      Current.with(user: agent) { card.triage_into(column) }
    else
      raise ArgumentError, "Unknown outcome: #{outcome.inspect}"
    end
  end

  private_class_method def self.build_comment_body(result:, summary:, details_html:, artifacts:)
    label = result_label(result)
    parts = [ "<p><strong>#{ERB::Util.html_escape(label)}</strong> · #{ERB::Util.html_escape(summary)}</p>" ]
    parts << sanitize_details(details_html) if details_html.present?
    if artifacts.present?
      list = artifacts.map { |a|
        url = a["url"] || a[:url]
        lbl = a["label"] || a[:label]
        "<li><a href=\"#{ERB::Util.html_escape(url)}\" target=\"_blank\" rel=\"noopener\">#{ERB::Util.html_escape(lbl)}</a></li>"
      }.join
      parts << "<ul>#{list}</ul>"
    end
    parts.join
  end

  private_class_method def self.result_label(result)
    I18n.t("cards.agent_completions.results.#{result}", default: result.to_s.titleize)
  end

  private_class_method def self.sanitize_details(html)
    ActionController::Base.helpers.sanitize(
      html,
      tags: %w[ p ul ol li a strong em b i u code pre blockquote br h1 h2 h3 h4 ],
      attributes: %w[ href target rel ]
    )
  end

  private
    def artifacts_within_limit
      list = particulars.is_a?(Hash) ? (particulars["artifacts"] || particulars[:artifacts] || []) : []
      errors.add(:artifacts, "exceeds #{MAX_ARTIFACTS} entries") if list.size > MAX_ARTIFACTS
    end
end

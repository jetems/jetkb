class Card::Eventable::SystemCommenter
  attr_reader :card, :event

  def initialize(card, event)
    @card, @event = card, event
  end

  def comment
    return unless comment_body.present?

    card.comments.create! creator: card.account.system_user, body: comment_body, created_at: event.created_at
  end

  private
    def comment_body
      case event.action
      when "card_assigned"
        I18n.t("cards.eventable.system_commenter.assigned_html", creator: creator_name, assignees: assignee_names)
      when "card_unassigned"
        I18n.t("cards.eventable.system_commenter.unassigned_html", creator: creator_name, assignees: assignee_names)
      when "card_closed"
        I18n.t("cards.eventable.system_commenter.closed_html", creator: creator_name)
      when "card_reopened"
        I18n.t("cards.eventable.system_commenter.reopened_html", creator: creator_name)
      when "card_postponed"
        I18n.t("cards.eventable.system_commenter.postponed_html", creator: creator_name)
      when "card_auto_postponed"
        I18n.t("cards.eventable.system_commenter.auto_postponed_html")
      when "card_title_changed"
        I18n.t("cards.eventable.system_commenter.title_changed_html", creator: creator_name, old_title: old_title, new_title: new_title)
      when "card_board_changed"
        I18n.t("cards.eventable.system_commenter.board_changed_html", creator: creator_name, old_board: old_board, new_board: new_board)
      when "card_triaged"
        I18n.t("cards.eventable.system_commenter.triaged_html", creator: creator_name, column: column)
      when "card_sent_back_to_triage"
        I18n.t("cards.eventable.system_commenter.sent_back_to_triage_html", creator: creator_name)
      end
    end

    def creator_name
      event.creator.name
    end

    def assignee_names
      event.assignees.pluck(:name).to_sentence
    end

    def old_title
      event.particulars.dig("particulars", "old_title")
    end

    def new_title
      event.particulars.dig("particulars", "new_title")
    end

    def old_board
      event.particulars.dig("particulars", "old_board")
    end

    def new_board
      event.particulars.dig("particulars", "new_board")
    end

    def column
      event.particulars.dig("particulars", "column")
    end
end

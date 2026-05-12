class Event::Description
  include ActionView::Helpers::TagHelper
  include ERB::Util

  attr_reader :event, :user

  def initialize(event, user)
    @event = event
    @user = user
  end

  def to_html
    to_sentence(creator_tag, card_title_tag).html_safe
  end

  def to_plain_text
    to_sentence(creator_name, quoted(card.title)).html_safe
  end

  private
    def to_sentence(creator, card_title)
      if event.action.comment_created?
        comment_sentence(creator, card_title)
      else
        action_sentence(creator, card_title)
      end
    end

    def creator_tag
      tag.span data: { creator_id: event.creator.id } do
        tag.span(I18n.t("events.description.creator_you"), data: { only_visible_to_you: true }) +
        tag.span(event.creator.name, data: { only_visible_to_others: true })
      end
    end

    def card_title_tag
      tag.span card.title, class: "txt-underline"
    end

    def creator_name
      h event.creator.name
    end

    def quoted(text)
      h %("#{text}")
    end

    def card
      @card ||= event.action.comment_created? ? event.eventable.card : event.eventable
    end

    def comment_sentence(creator, card_title)
      I18n.t("events.description.comment_created", creator: creator, card: card_title).html_safe
    end

    def action_sentence(creator, card_title)
      case event.action
      when "card_assigned"
        assigned_sentence(creator, card_title)
      when "card_unassigned"
        unassigned_sentence(creator, card_title)
      when "card_published"
        I18n.t("events.description.card_published", creator: creator, card: card_title).html_safe
      when "card_closed"
        I18n.t("events.description.card_closed", creator: creator, card: card_title).html_safe
      when "card_reopened"
        I18n.t("events.description.card_reopened", creator: creator, card: card_title).html_safe
      when "card_postponed"
        I18n.t("events.description.card_postponed", creator: creator, card: card_title).html_safe
      when "card_auto_postponed"
        I18n.t("events.description.card_auto_postponed", card: card_title).html_safe
      when "card_resumed"
        I18n.t("events.description.card_resumed", creator: creator, card: card_title).html_safe
      when "card_title_changed"
        renamed_sentence(creator, card_title)
      when "card_board_changed", "card_collection_changed"
        moved_sentence(creator, card_title)
      when "card_triaged"
        triaged_sentence(creator, card_title)
      when "card_sent_back_to_triage"
        I18n.t("events.description.card_sent_back_to_triage", creator: creator, card: card_title).html_safe
      end
    end

    def assigned_sentence(creator, card_title)
      if event.assignees.include?(user)
        I18n.t("events.description.assigned_self", creator: creator, card: card_title).html_safe
      else
        I18n.t("events.description.assigned_other", creator: creator, assignees: assignee_names, card: card_title).html_safe
      end
    end

    def unassigned_sentence(creator, card_title)
      I18n.t("events.description.unassigned", creator: creator, assignees: unassigned_names, card: card_title).html_safe
    end

    def renamed_sentence(creator, card_title)
      I18n.t("events.description.renamed", creator: creator, card: card_title, old_title: old_title).html_safe
    end

    def moved_sentence(creator, card_title)
      I18n.t("events.description.moved", creator: creator, card: card_title, location: new_location).html_safe
    end

    def triaged_sentence(creator, card_title)
      I18n.t("events.description.triaged", creator: creator, card: card_title, column: column).html_safe
    end

    def assignee_names
      h event.assignees.pluck(:name).to_sentence
    end

    def unassigned_names
      event.assignees.include?(user) ? I18n.t("events.description.yourself") : assignee_names
    end

    def old_title
      h event.particulars.dig("particulars", "old_title")
    end

    def new_location
      h(event.particulars.dig("particulars", "new_board") || event.particulars.dig("particulars", "new_collection"))
    end

    def column
      h event.particulars.dig("particulars", "column")
    end
end

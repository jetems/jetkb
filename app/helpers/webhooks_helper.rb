module WebhooksHelper
  ACTION_KEYS = %i[
    card_published
    card_title_changed
    card_board_changed
    comment_created
    card_assigned
    card_unassigned
    card_triaged
    card_closed
    card_reopened
    card_postponed
    card_auto_postponed
    card_sent_back_to_triage
  ].freeze

  def webhook_action_options(actions = Webhook::PERMITTED_ACTIONS)
    ACTION_KEYS.select { |key| actions.include?(key.to_s) }.map { |key| [ key.to_s, webhook_action_label(key) ] }
  end

  def webhook_action_label(action)
    return action.to_s.humanize unless ACTION_KEYS.include?(action.to_sym)

    I18n.t("webhooks.actions.#{action}")
  end

  def link_to_webhooks(board, &)
    link_to board_webhooks_path(board_id: board),
        class: [ "btn btn--circle-mobile", { "btn--reversed": board.webhooks.any? } ],
        data: { controller: "tooltip", bridge__overflow_menu_target: "item", bridge_title: I18n.t("webhooks.link_title") } do
      icon_tag("world") + tag.span(I18n.t("webhooks.link_title"), class: "for-screen-reader")
    end
  end
end

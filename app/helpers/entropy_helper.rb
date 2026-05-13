module EntropyHelper
  def entropy_bubble_options_for(card)
    {
      daysBeforeReminder: card.entropy.days_before_reminder,
      closesAt: card.entropy.auto_clean_at.iso8601,
      labels: {
        topImmediate: t("cards.bubble.entropy.top_immediate"),
        topFuture: t("cards.bubble.entropy.top_future"),
        centerImmediate: t("cards.bubble.entropy.center_immediate"),
        bottomImmediate: t("cards.bubble.entropy.bottom_immediate"),
        bottomSingular: t("cards.bubble.entropy.bottom_singular"),
        bottomPlural: t("cards.bubble.entropy.bottom_plural")
      }
    }
  end

  def stalled_bubble_options_for(card)
    if card.last_activity_spike_at
      {
        stalledAfterDays: card.entropy.days_before_reminder,
        lastActivitySpikeAt: card.last_activity_spike_at.iso8601,
        updatedAt: card.updated_at.iso8601,
        labels: {
          top: t("cards.bubble.stalled.top"),
          bottom: t("cards.bubble.stalled.bottom")
        }
      }
    end
  end
end

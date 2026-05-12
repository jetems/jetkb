module CommentsHelper
  def new_comment_placeholder(card)
    if card.creator == Current.user && card.comments.empty?
      I18n.t("cards.comments.placeholder.first")
    else
      I18n.t("cards.comments.placeholder.default")
    end
  end
end

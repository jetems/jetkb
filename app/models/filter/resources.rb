module Filter::Resources
  extend ActiveSupport::Concern

  included do
    has_and_belongs_to_many :tags
    has_and_belongs_to_many :boards
    has_and_belongs_to_many :assignees, class_name: "User", join_table: "assignees_filters", association_foreign_key: "assignee_id"
    has_and_belongs_to_many :creators, class_name: "User", join_table: "creators_filters", association_foreign_key: "creator_id"
    has_and_belongs_to_many :closers, class_name: "User", join_table: "closers_filters", association_foreign_key: "closer_id"
  end

  def resource_removed(resource)
    kind = resource.class.model_name.plural
    self.class.transaction(requires_new: true) do
      send "#{kind}=", send(kind).without(resource)
      @boards = nil
      empty? ? destroy! : save!
    end
  rescue ActiveRecord::RecordNotUnique
    # PG aborts the outer transaction on a unique violation; the savepoint
    # above is rolled back automatically so this destroy! runs cleanly.
    destroy!
  end

  def boards
    @boards ||= creator.boards.where id: super.ids
  end

  def board_titles
    if boards.none?
      creator.boards.one? ? [ creator.boards.first.name ] : [ "all boards" ]
    else
      boards.map(&:name)
    end
  end

  def boards_label
    board_titles.to_sentence
  end
end

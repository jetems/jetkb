module User::Role
  extend ActiveSupport::Concern

  included do
    enum :role, %i[ owner admin member system agent ].index_by(&:itself), scopes: false

    scope :owner,      -> { where(active: true, role: :owner) }
    scope :admin,      -> { where(active: true, role: %i[ owner admin ]) }
    scope :member,     -> { where(active: true, role: :member) }
    scope :agent,      -> { where(active: true, role: :agent) }
    scope :active,     -> { where(active: true, role: %i[ owner admin member ]) }
    scope :api_active, -> { where(active: true, role: %i[ owner admin member agent ]) }

    def admin?
      super || owner?
    end
  end

  def agent?
    role == "agent"
  end

  def api_active?
    active? && role.in?(%w[ owner admin member agent ])
  end

  def can_change?(other)
    (admin? && !other.owner?) || other == self
  end

  def can_administer?(other)
    admin? && !other.owner? && other != self
  end

  def can_administer_board?(board)
    admin? || board.creator == self
  end

  def can_administer_card?(card)
    admin? || card.creator == self
  end
end

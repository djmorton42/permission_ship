# The tenant. A school board, or an independent school. Global table.
class Organization < ApplicationRecord
  has_many :schools
  has_many :users

  validates :name, presence: true
end

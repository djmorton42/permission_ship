# typed: strict

# A user who administers a school, as an admin or an assistant admin. Capability: Accounts.
class SchoolAdministrator < ApplicationRecord
  belongs_to :organization
  belongs_to :school
  belongs_to :user

  enum :role, { admin: "admin", assistant_admin: "assistant_admin" }, validate: true

  # The school's administrators, locked. Commands that change a school's administrators
  # lock them first, so two changes cannot both pass the "one admin" rule.
  scope :locked_for_school, ->(school_id) { where(school_id:).order(:id).lock }
end

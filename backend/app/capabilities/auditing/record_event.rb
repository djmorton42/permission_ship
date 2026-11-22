# typed: strict

# Records an audit event. Other commands call it, so the event commits or rolls
# back with their change. See "Auditing" in ../../../architecture.md.
class Auditing::RecordEvent < ApplicationCommand
  # The actor is a user, or an operator for operations work (for example, "Ops: Avery Lin, ticket ONB-42").
  attribute :actor_user_id, :string
  attribute :operator_reference, :string
  # <subject>.<past-tense verb>, for example "school_administrator.role_changed".
  attribute :action, :string
  attribute :subject_type, :string
  attribute :subject_id, :string
  # Changed attributes as { "attribute" => [before, after] }.
  attribute :details, default: -> { {} }

  validates :action, :subject_type, :subject_id, presence: true
  validate :one_actor

  sig { override.returns(UseCaseResult[NilClass]) }
  def perform
    AuditEvent.create!(organization_id:, actor_user_id:, operator_reference:, action:, subject_type:, subject_id:,
                       details:)
    success(nil)
  end

  private

  sig { void }
  def one_actor
    return if [ actor_user_id, operator_reference ].count(&:present?) == 1

    errors.add(:base, :one_actor_required, message: "Give a user or an operator as the actor, not both.")
  end
end

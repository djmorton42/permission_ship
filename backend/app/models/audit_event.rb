# typed: strict

# A record of a change: who made it, what changed, and when. Append-only.
# Capability: Auditing.
class AuditEvent < ApplicationRecord
  belongs_to :organization
  belongs_to :actor_user, class_name: "User", optional: true
end

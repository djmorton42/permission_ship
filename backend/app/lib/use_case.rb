# Shared shape of ApplicationCommand and ApplicationQuery: attributes,
# validation, dependencies and the organization (tenant).
module UseCase
  extend ActiveSupport::Concern
  include ActiveModel::Model
  include ActiveModel::Attributes

  included do
    class_attribute :dependency_defaults, instance_writer: false, default: {}
    class_attribute :requires_organization, instance_accessor: false, default: true

    # The tenant. Required unless the class calls runs_without_organization.
    attribute :organization_id, :string
    validates :organization_id, presence: true, if: -> { self.class.requires_organization }
  end

  class_methods do
    # call(inputs, **dependencies) or call(**inputs_and_dependencies).
    # Keywords that name a declared dependency are dependencies. Others are inputs.
    def call(inputs = {}, **keywords)
      dependencies = keywords.slice(*dependency_defaults.keys)
      new(inputs.to_h.merge(keywords.except(*dependency_defaults.keys)), dependencies).run
    end

    # Declares an injected boundary. Tests pass a fake to call.
    def dependency(name, default:)
      self.dependency_defaults = dependency_defaults.merge(name => default)
      define_method(name) { @dependencies.fetch(name) { @dependencies[name] = dependency_defaults.fetch(name).call } }
    end

    # For global work: login, and the organizations table itself.
    def runs_without_organization
      self.requires_organization = false
    end
  end

  def initialize(inputs, dependencies)
    @dependencies = dependencies.dup
    super(inputs)
  end

  private

  def perform
    raise NotImplementedError, "#{self.class.name} must define perform"
  end

  def success(value = nil) = UseCaseResult.success(value)

  def failure(category, field: nil, code:, message:)
    UseCaseResult.failure(category, [ UseCaseResult::Error.new(field:, code:, message:) ])
  end

  def validation_failure
    UseCaseResult.failure(:validation, errors.map do |error|
      UseCaseResult::Error.new(field: error.attribute, code: error.type, message: error.message)
    end)
  end

  def in_organization(&)
    return yield unless self.class.requires_organization

    Tenancy.with_organization(organization_id, &)
  end
end

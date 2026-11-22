# typed: strict

# Base class of ApplicationCommand and ApplicationQuery: attributes,
# validation, dependencies and the organization (tenant).
#
# sorbet/tapioca/compilers/use_case.rb generates the types of each subclass's
# dependency readers and of its call method. Run bin/tapioca dsl after a change.
class UseCase
  extend T::Sig
  extend T::Helpers
  include ActiveModel::Model
  include ActiveModel::Attributes

  abstract!

  Inputs = T.type_alias { T::Hash[T.any(String, Symbol), T.anything] }

  # An injected boundary. See "Dependencies" in ../../architecture.md.
  class Dependency < T::Struct
    # The class or module that the value and every fake must be.
    const :type, T::Module[T.anything]
    const :default, T.proc.returns(Object)
  end

  # The tenant. Required unless the class calls runs_without_organization.
  attribute :organization_id, :string
  validates :organization_id, presence: true, if: :requires_organization?

  class << self
    extend T::Sig

    # call(inputs, **dependencies) or call(**inputs_and_dependencies).
    # Keywords that name a declared dependency are dependencies. Others are inputs.
    sig { params(inputs: Inputs, keywords: Object).returns(UseCaseResult[T.anything]) }
    def call(inputs = {}, **keywords)
      injected = keywords.select { |name, _| dependencies.key?(name) }
      new(inputs.to_h.merge(keywords.reject { |name, _| injected.key?(name) }), injected).run
    end

    sig { returns(T::Hash[Symbol, Dependency]) }
    def dependencies = {}

    # Declares an injected boundary. Tests pass a fake to call.
    sig { params(name: Symbol, type: T::Module[T.anything], default: T.proc.returns(Object)).void }
    def dependency(name, type:, default:)
      all = dependencies.merge(name => Dependency.new(type:, default:)).freeze
      # Like class_attribute: subclasses inherit the singleton method.
      define_singleton_method(:dependencies) { all }
      define_method(name) do
        # define_method runs the block on an instance, not on the class.
        T.bind(self, UseCase)
        dependency_value(name)
      end
    end

    sig { returns(T::Boolean) }
    def requires_organization? = true

    # For global work: login, and the organizations table itself.
    sig { void }
    def runs_without_organization
      define_singleton_method(:requires_organization?) { false }
    end
  end

  sig { params(inputs: Inputs, dependencies: T::Hash[Symbol, Object]).void }
  def initialize(inputs, dependencies)
    @dependencies = T.let(dependencies.dup, T::Hash[Symbol, Object])
    super(inputs)
  end

  sig { abstract.returns(UseCaseResult[T.anything]) }
  def run; end

  private

  sig { abstract.returns(UseCaseResult[T.anything]) }
  def perform; end

  sig { returns(T::Boolean) }
  def requires_organization? = self.class.requires_organization?

  sig { params(name: Symbol).returns(Object) }
  def dependency_value(name)
    dependency = self.class.dependencies.fetch(name)
    value = @dependencies.fetch(name) { @dependencies[name] = dependency.default.call }
    return value if value.is_a?(dependency.type)

    raise TypeError, "#{self.class.name} dependency #{name} must be a #{dependency.type}, not #{value.class}"
  end

  sig { type_parameters(:V).params(value: T.type_parameter(:V)).returns(UseCaseResult::Success[T.type_parameter(:V)]) }
  def success(value) = UseCaseResult.success(value)

  sig { params(category: Symbol, code: String, message: String, field: T.nilable(Symbol)).returns(UseCaseResult::Failure) }
  def failure(category, code:, message:, field: nil)
    UseCaseResult.failure(category, [ UseCaseResult::Error.new(field:, code:, message:) ])
  end

  sig { returns(UseCaseResult::Failure) }
  def validation_failure
    UseCaseResult.failure(:validation, errors.map do |error|
      # An error on :base is not about one field.
      field = error.attribute == :base ? nil : error.attribute
      UseCaseResult::Error.new(field:, code: error.type, message: error.message)
    end)
  end

  sig do
    type_parameters(:R)
      .params(block: T.proc.returns(T.type_parameter(:R)))
      .returns(T.type_parameter(:R))
  end
  def in_organization(&block)
    return yield unless requires_organization?

    Tenancy.with_organization(organization_id, &block)
  end
end

# typed: strict

# The result of a command or query. See "Results and errors" in ../../architecture.md.
#
# A result is a Success with a value, or a Failure with a category and errors.
# Value is covariant: a Failure is a UseCaseResult of every value type.
module UseCaseResult
  extend T::Sig
  extend T::Generic
  extend T::Helpers

  abstract!
  sealed!
  requires_ancestor { Object }

  Value = type_member(:out)

  CATEGORIES = %i[validation unauthenticated forbidden not_found conflict].freeze

  # Raised when code reads the value of a failure. Check failure? first.
  class NoValueError < StandardError; end

  # One error in a failure. field is nil when the error is not about one field.
  class Error
    extend T::Sig

    sig { returns(T.nilable(String)) }
    attr_reader :field

    sig { returns(String) }
    attr_reader :code

    sig { returns(String) }
    attr_reader :message

    sig { params(field: T.nilable(T.any(String, Symbol)), code: T.any(String, Symbol), message: String).void }
    def initialize(field:, code:, message:)
      @field = T.let(field&.to_s, T.nilable(String))
      @code = T.let(code.to_s, String)
      @message = message
      freeze
    end

    sig { returns(T::Hash[Symbol, T.nilable(String)]) }
    def to_h = { field:, code:, message: }
  end

  class Success
    extend T::Sig
    extend T::Generic
    include UseCaseResult

    Value = type_member

    sig { override.returns(Value) }
    attr_reader :value

    sig { params(value: Value).void }
    def initialize(value)
      @value = value
      freeze
    end

    sig { override.returns(NilClass) }
    def category = nil

    sig { override.returns(T::Array[Error]) }
    def errors = []

    sig { override.returns(T::Boolean) }
    def success? = true
  end

  class Failure
    extend T::Sig
    extend T::Generic
    include UseCaseResult

    Value = type_member { { fixed: T.noreturn } }

    sig { override.returns(Symbol) }
    attr_reader :category

    sig { override.returns(T::Array[Error]) }
    attr_reader :errors

    sig { params(category: Symbol, errors: T::Array[Error]).void }
    def initialize(category, errors)
      raise ArgumentError, "unknown failure category: #{category}" unless CATEGORIES.include?(category)

      @category = category
      @errors = T.let(errors.dup.freeze, T::Array[Error])
      freeze
    end

    sig { override.returns(T.noreturn) }
    def value
      raise NoValueError, "a failure has no value"
    end

    sig { override.returns(T::Boolean) }
    def success? = false
  end

  sig { type_parameters(:V).params(value: T.type_parameter(:V)).returns(Success[T.type_parameter(:V)]) }
  def self.success(value) = Success.new(value)

  sig { params(category: Symbol, errors: T::Array[Error]).returns(Failure) }
  def self.failure(category, errors) = Failure.new(category, errors)

  sig { abstract.returns(Value) }
  def value; end

  sig { abstract.returns(T.nilable(Symbol)) }
  def category; end

  sig { abstract.returns(T::Array[Error]) }
  def errors; end

  sig { abstract.returns(T::Boolean) }
  def success?; end

  sig { returns(T::Boolean) }
  def failure? = !success?
end

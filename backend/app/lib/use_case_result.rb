# The result of a command or query. See "Results and errors" in ../architecture.md.
class UseCaseResult
  CATEGORIES = %i[validation unauthenticated forbidden not_found conflict].freeze

  Error = Data.define(:field, :code, :message) do
    def initialize(field:, code:, message:)
      super(field: field&.to_s, code: code.to_s, message:)
    end
  end

  attr_reader :value, :errors, :category

  def self.success(value = nil) = new(value:)

  def self.failure(category, errors)
    raise ArgumentError, "unknown failure category: #{category}" unless CATEGORIES.include?(category)

    new(category:, errors:)
  end

  def initialize(value: nil, category: nil, errors: [])
    @value = value
    @category = category
    @errors = errors.freeze
    freeze
  end

  def success? = category.nil?
  def failure? = !success?
end

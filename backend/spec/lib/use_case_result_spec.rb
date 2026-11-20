# typed: false

require "rails_helper"

RSpec.describe UseCaseResult do
  it "has no value when it is a failure" do
    result = UseCaseResult.failure(:not_found, [ UseCaseResult::Error.new(field: nil, code: "missing", message: "Not found.") ])

    expect { result.value }.to raise_error(UseCaseResult::NoValueError)
  end

  it "rejects an unknown failure category" do
    expect { UseCaseResult.failure(:teapot, []) }.to raise_error(ArgumentError, /unknown failure category: teapot/)
  end
end

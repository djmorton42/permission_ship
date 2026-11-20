# typed: strict

# The ID and name of a record, for lists and headings in responses.
class RecordSummary < T::Struct
  const :id, String
  const :name, String
end

# typed: strict
# frozen_string_literal: true

return unless defined?(UseCase)

module Tapioca
  module Compilers
    # Types for the UseCase DSL (app/lib/use_case.rb). For each command and query:
    #
    # - a reader for each dependency that the class declares, with the dependency's type;
    # - call, which returns the type that perform returns.
    #
    # The built-in ActiveModelAttributes compiler types the attributes.
    class UseCase < Tapioca::Dsl::Compiler
      extend T::Sig

      ConstantType = type_member { { fixed: T.class_of(::UseCase) } }

      sig { override.returns(T::Enumerable[T::Module[T.anything]]) }
      def self.gather_constants
        all_classes.select { |klass| klass < ::UseCase && klass.name }
      end

      sig { override.void }
      def decorate
        dependencies = own_dependencies
        perform = own_perform
        return if dependencies.empty? && perform.nil?

        root.create_path(constant) do |klass|
          dependencies.each do |name, dependency|
            klass.create_method(name.to_s, return_type: qualified_name_of(dependency.type) || "T.anything")
          end
          create_call(klass, perform) if perform
        end
      end

      private

      sig { returns(T::Hash[Symbol, ::UseCase::Dependency]) }
      def own_dependencies
        constant.dependencies.select { |name, _| constant.instance_method(name).owner == constant }
      end

      sig { returns(T.nilable(UnboundMethod)) }
      def own_perform
        perform = constant.instance_method(:perform)
        perform if perform.owner == constant && signature_of(perform)
      end

      sig { params(klass: RBI::Scope, perform: UnboundMethod).void }
      def create_call(klass, perform)
        klass.create_method(
          "call",
          parameters: [
            create_opt_param("inputs", type: "::UseCase::Inputs", default: "{}"),
            create_kw_rest_param("keywords", type: "Object")
          ],
          return_type: compile_method_return_type_to_rbi(perform),
          class_method: true
        )
      end
    end
  end
end

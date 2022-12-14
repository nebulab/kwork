# frozen_string_literal: true

require "kwork/executor"
require "kwork/result_adapter"

module Kwork
  # Base class to define business transactions
  class Transaction
    NULL_EXTENSION = ->(&block) { block.() }

    def self.with_delegation
      include(MethodMissing)
    end

    def initialize(
      operations:,
      adapter: ResultAdapter,
      executor: Executor.new(methods: operations, adapter: adapter),
      extension: NULL_EXTENSION
    )
      @operations = operations
      @executor = executor
      @adapter = adapter
      @extension = extension
    end

    def transaction(&block)
      result = nil
      @extension.() do
        result = catch(:halt) do
          @adapter.wrap(
            block.(@executor)
          )
        end
      end
      result
    end

    def with(**operations)
      new_operations = @operations.merge(operations)

      self.class.new(
        operations: new_operations,
        adapter: @adapter,
        executor: Executor.new(methods: new_operations, adapter: @adapter)
      )
    end

    # Avoids the need to call from the executor
    module MethodMissing
      def method_missing(name, *args, **kwargs)
        @operations.key?(name) ? @executor.(name, *args, **kwargs) : super
      end

      def respond_to_missing?(name, include_all)
        @operations.key?(name) || super
      end
    end
  end
end

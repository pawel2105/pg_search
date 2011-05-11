require "active_support/core_ext/module/delegation"

module PgSearch
  module Features
    class Trigram < PgSearch::Features::Feature
      def conditions
        ["(#{@normalizer.add_normalization(document)}) % #{@normalizer.add_normalization(":query")}", {:query => @query}]
      end

      def rank
        ["similarity((#{@normalizer.add_normalization(document)}), #{@normalizer.add_normalization(":query")})", {:query => @query}]
      end

      private

      def document
        @columns.map { |column| column.to_sql }.join(" || ' ' || ")
      end
    end
  end
end

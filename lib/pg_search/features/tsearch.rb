require "active_support/core_ext/module/delegation"

module PgSearch
  module Features
    class TSearch
      delegate :connection, :quoted_table_name, :to => :'@model'

      # config is temporary as we refactor
      def initialize(query, options, config, model, normalizer)
        @query = query
        @options = options || {}
        @config = config
        @model = model
        @normalizer = normalizer
      end

      def conditions
        ["(#{tsdocument}) @@ (#{tsquery})", interpolations]
      end

      def rank
        tsearch_rank
      end

      private

      def interpolations
        {:query => @query.to_s, :dictionary => @options[:dictionary].to_s}
      end

      def columns_with_weights
        @config.search_columns
      end

      def document
        columns_with_weights.map { |column, *| column }.join(" || ' ' || ")
      end

      def tsquery
      	return "''" if @query.blank?

        @query.split(" ").compact.map do |term|
          sanitized_term = term.gsub(/['?\-\\]/, " ")

          term_sql = @normalizer.add_normalization(connection.quote(sanitized_term))

          # After this, the SQL expression evaluates to a string containing the term surrounded by single-quotes.
          tsquery_sql = "#{connection.quote("'")} || #{term_sql} || #{connection.quote("'")}"

          # Add tsearch prefix operator if we're using a prefix search.
          tsquery_sql = "#{tsquery_sql} || #{connection.quote(':*')}" if @options[:prefix]

          "to_tsquery(#{":dictionary," if @options[:dictionary]} #{tsquery_sql})"
        end.join(" && ")
      end

      def tsdocument
        columns_with_weights.map do |column, weight|
          tsvector = "to_tsvector(#{":dictionary," if @options[:dictionary]} #{@normalizer.add_normalization(column)})"
          weight.nil? ? tsvector : "setweight(#{tsvector}, #{connection.quote(weight)})"
        end.join(" || ")
      end

      def tsearch_rank
        ["ts_rank((#{tsdocument}), (#{tsquery}))", interpolations]
      end
    end
  end
end

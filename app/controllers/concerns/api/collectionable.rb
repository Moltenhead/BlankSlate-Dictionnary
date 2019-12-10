# frozen_string_literal: true

# app/hermes/models/concerns/collactionable.rb

module Concerns
  module Api
    # add query handlers
    module Collectionable
      extend ActiveSupport::Concern

      included do
        include Assets::Parameters::Querestrict

        # ========================================== #
        # --------------- UTILITIES  --------------- #
        # ========================================== #
        %i[
          acceptable_params
          regex_default_params
          regex_params
          valid_operators
          included_relationships
        ].each do |method_name|
          define_method(method_name) do |value = []|
            instance_variable_set(method_name, value || [])
          end
        end

        # handle query parameters and query operators
        def build_query(other_model = nil)
        # @other_model: when nil use @model, else use passed model
        #   - needed for value type handling
          query = {}
          params.each do |key, value|
            # find parameters beginning by "search_"
            if ((match = key =~ /^search_([\w]*)$/) && (@regex_params.include?(target_key = match[1])) || (@regex_default_params.include?(target_key == key)))
              query[target_key.to_sym] = Regexp.new(value)  # turn it into regex
              params.delete(key)                            # then remove it from parameters
            # handle ids paramter => query for every id passed within array
            elsif key == 'ids' && @acceptable_params.include?('ids')
              query["id"] = {"$in"=>value}
            end
          end

          valid_params = params.slice(*@acceptable_params)  # slice only valid parameters from 

          model = other_model || @model
          # handle parameters value type using 'model' local variable
          valid_params.each do |key, value|
            next if !model || model.fields[key].nil?

            field_type = model.fields[key].type.name.demodulize
            query[key.to_sym] = case value.class.name
                                when /(ActionController::Parameters|Hash|Mongoi::Document)/
                                  value.each_with_object({}) do |(sub_key, sub_value), h|
                                    h[sub_key.to_sym] = format_parameter(field_type, sub_value) if @valid_operators.include? sub_key
                                  end
                                else
                                  format_parameter(field_type, value) || {:$eq => nil}
                                end
          end
          query
        end

        def format_parameter(type, param)
          if %w[ActionController::Parameters Hash].include?(param.class.name)
            param.to_hash.each_with_object({}) do |(sf_k, sf_v), x|
              x[sf_k] = format_value(type, sf_v) if @valid_operators.include?(sf_k)
            end
          else
            formated = format_value(type, param)
            if formated.is_a?(NilClass)
              { :$eq => nil }
            elsif formated.is_a?(FalseClass)
              { :$eq => false }
            else
              formated
            end
          end
        end

        def handle_order_param(val)
          return unless [1, -1, '1', '-1', 'asc', 'desc', :asc, :desc].include?(val)

          val = Integer(val) if ['1', '-1'].include?(val)
          if [1,-1].include? val
            val == 1 ? :asc : :desc
          elsif %w[asc desc].include?(val)
            val.to_sym
          else
            val
          end
        end

        def index_aggregation(target_model: @model, no_acl: false)
          return unless target_model

          precision = @query_precision || {}
          precision[:user_id] = params[:responsible] if params[:responsible]
          query = target_model
          query = query.readable_by(@user) unless no_acl
          query.where(build_query(target_model).deep_merge(precision))
               .order_by(order_params)
               .includes(@include_relationships)
        end

        def order_params
          if %w[
            ActionController::Parameters
            Mongoid::Document
            Hash
          ].include?(params[:sort].class.name)
            params[:sort].each_with_object({}) do |(key, val), h|
              next unless handle_order_param(val)

              h[key] = handle_order_param(val)
            end
          end
        end

        def paginate(aggregation, options = {})
          page = params[:page][:number] || 1
          page_size = params[:page][:size] || 15
          paginated_aggregation = aggregation.skip((page - 1) * page_size).limit(page_size)

          render(
            paginated_aggregation,
            **options
          )
        end

        # ========================================== #
        # ---------------- ACTIONS  ---------------- #
        # ========================================== #
        def index
          paginate(
            index_aggregation,
            each_serializer: @serializer,
            **@options
          )
        end
      end
    end
  end
end
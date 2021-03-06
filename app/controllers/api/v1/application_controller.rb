# frozen_string_literal: true

module Api
  module V1
    class ApplicationController < ActionController::Base
      include Concerns::Api::Structuralizers::Collectionable
      include Concerns::Api::Structuralizers::Instanceable
      include Concerns::Api::Structuralizers::Showable
      include Concerns::Api::Structuralizers::Mutable
      include Concerns::Api::Structuralizers::Creatable
      include Concerns::Api::Structuralizers::Updatable
      include Concerns::Api::Structuralizers::Destroyable

      before_action :set_instance, only: %i[show edit update destroy]
      skip_before_action :verify_authenticity_token

      MODEL_MODULE = ''

      # INTIALIZE
      def initialize
        super
        @model_name = ((self.class::MODEL_MODULE ? "#{self.class::MODEL_MODULE}::" : '') +
                        controller_name.capitalize).classify
        begin
          if @model_name && @model_name != 'Application'
            @model = @model_name.constantize
            @serializer = "#{@model_name}Serializer".constantize
          end
        rescue NameError => e
          Rails.logger.warn "TEST was unable to process model or serializer #{e}"
        end
        @acceptable_params = @regex_params = @regex_default_params = @regex_params = @valid_operators = []
      end

      attr_reader :serializer
      attr_accessor(
        :model_name,
        :acceptable_params,
        :regex_default_params,
        :regex_params,
        :valid_operators,
        :included_relationships
      )

      def serializer
        @serializer
      end

      # %i[
      #   acceptable_params
      #   regex_default_params
      #   regex_params
      #   valid_operators
      #   included_relationships
      # ].each do |method_name|
      #   attr_accessor method_name
      #   define_method(method_name) do |value = []|
      #     instance_variable_set(method_name, value || [])
      #   end
      # end

      # def render(resources, options = {})
      #   options   = options.dup
      #   klass     = options.delete(:class) || {}
      #   exposures = options.delete(:expose) || {}
      #   exposures = exposures.merge(_class: klass)

      #   resources =
      #     JSONAPI::Serializable.resources_for(resources, exposures, klass)
      #   puts options
      #   puts @renderer.render(options.merge(data: resources))

      #   @renderer.render(options.merge(data: resources))
      # end

      # def render_errors(errors, options = {})
      #   options   = options.dup
      #   klass     = options.delete(:class) || {}
      #   exposures = options.delete(:expose) || {}

      #   errors =
      #     JSONAPI::Serializable.resources_for(errors, exposures, klass)

      #   @renderer.render(options.merge(errors: errors))
      # end
    end
  end
end

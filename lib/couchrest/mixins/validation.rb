# Extracted from dm-validations 0.9.10
#
# Copyright (c) 2007 Guy van den Berg
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'rubygems'
require 'pathname'

class Object
  def validatable?
    false
  end
end

dir = File.join(Pathname(__FILE__).dirname.expand_path, '..', 'validation')

require File.join(dir, 'validation_errors')
require File.join(dir, 'contextual_validators')

require File.join(dir, 'validators', 'generic_validator')
require File.join(dir, 'validators', 'required_field_validator')
require File.join(dir, 'validators', 'absent_field_validator')
require File.join(dir, 'validators', 'format_validator')
require File.join(dir, 'validators', 'length_validator')
require File.join(dir, 'validators', 'numeric_validator')
require File.join(dir, 'validators', 'method_validator')

module CouchRest
  module Validation
    
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Return the ValidationErrors
    #
    def errors
      @errors ||= ValidationErrors.new
    end

    # Mark this resource as validatable. When we validate associations of a
    # resource we can check if they respond to validatable? before trying to
    # recursivly validate them
    #
    def validatable?
      true
    end

    # Alias for valid?(:default)
    #
    def valid_for_default?
      valid?(:default)
    end

    # Check if a resource is valid in a given context
    #
    def valid?(context = :default)
      self.class.validators.execute(context, self)
    end

    # Begin a recursive walk of the model checking validity
    #
    def all_valid?(context = :default)
      recursive_valid?(self, context, true)
    end

    # Do recursive validity checking
    #
    def recursive_valid?(target, context, state)
      valid = state
      target.instance_variables.each do |ivar|
        ivar_value = target.instance_variable_get(ivar)
        if ivar_value.validatable?
          valid = valid && recursive_valid?(ivar_value, context, valid)
        elsif ivar_value.respond_to?(:each)
          ivar_value.each do |item|
            if item.validatable?
              valid = valid && recursive_valid?(item, context, valid)
            end
          end
        end
      end
      return valid && target.valid?
    end


    def validation_property_value(name)
      self.respond_to?(name, true) ? self.send(name) : nil
    end

    # Get the corresponding Resource property, if it exists.
    #
    # Note: CouchRest validations can be used on non-CouchRest resources.
    # In such cases, the return value will be nil.
    def validation_property(field_name)
      properties.find{|p| p.name == field_name}
    end

    module ClassMethods
      include CouchRest::Validation::ValidatesPresent
      include CouchRest::Validation::ValidatesAbsent
      # include CouchRest::Validation::ValidatesIsConfirmed
      # include CouchRest::Validation::ValidatesIsPrimitive
      # include CouchRest::Validation::ValidatesIsAccepted
      include CouchRest::Validation::ValidatesFormat
      include CouchRest::Validation::ValidatesLength
      # include CouchRest::Validation::ValidatesWithin
      include CouchRest::Validation::ValidatesIsNumber
      include CouchRest::Validation::ValidatesWithMethod
      # include CouchRest::Validation::ValidatesWithBlock
      # include CouchRest::Validation::ValidatesIsUnique
      # include CouchRest::Validation::AutoValidate

      # Return the set of contextual validators or create a new one
      #
      def validators
        @validations ||= ContextualValidators.new
      end
      
      # Clean up the argument list and return a opts hash, including the
      # merging of any default opts. Set the context to default if none is
      # provided. Also allow :context to be aliased to :on, :when & group
      #
      def opts_from_validator_args(args, defaults = nil)
        opts = args.last.kind_of?(Hash) ? args.pop : {}
        context = :default
        context = opts[:context] if opts.has_key?(:context)
        context = opts.delete(:on) if opts.has_key?(:on)
        context = opts.delete(:when) if opts.has_key?(:when)
        context = opts.delete(:group) if opts.has_key?(:group)
        opts[:context] = context
        opts.mergs!(defaults) unless defaults.nil?
        opts
      end
      
      # Given a new context create an instance method of
      # valid_for_<context>? which simply calls valid?(context)
      # if it does not already exist
      #
      def create_context_instance_methods(context)
        name = "valid_for_#{context.to_s}?"           # valid_for_signup?
        if !self.instance_methods.include?(name)
          class_eval <<-EOS, __FILE__, __LINE__
            def #{name}                               # def valid_for_signup?
              valid?('#{context.to_s}'.to_sym)        #   valid?('signup'.to_sym)
            end                                       # end
          EOS
        end

        all = "all_valid_for_#{context.to_s}?"        # all_valid_for_signup?
        if !self.instance_methods.include?(all)
          class_eval <<-EOS, __FILE__, __LINE__
            def #{all}                                # def all_valid_for_signup?
              all_valid?('#{context.to_s}'.to_sym)    #   all_valid?('signup'.to_sym)
            end                                       # end
          EOS
        end
      end

      # Create a new validator of the given klazz and push it onto the
      # requested context for each of the attributes in the fields list
      #
      def add_validator_to_context(opts, fields, klazz)
        fields.each do |field|
          validator = klazz.new(field, opts)
          if opts[:context].is_a?(Symbol)
            unless validators.context(opts[:context]).include?(validator)
              validators.context(opts[:context]) << validator
              create_context_instance_methods(opts[:context])
            end
          elsif opts[:context].is_a?(Array)
            opts[:context].each do |c|
              unless validators.context(c).include?(validator)
                validators.context(c) << validator
                create_context_instance_methods(c)
              end
            end
          end
        end
      end
      
    end # module ClassMethods
  end # module Validation

end # module CouchRest

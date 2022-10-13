require "yaml"

module RailsMermaidErd
  class Builder
    class << self
      def model_data
        result = {
          Models: [],
          Relations: []
        }

        ::Rails.application.eager_load!
        ::ActiveRecord::Base.descendants.each do |defined_model|
          next unless defined_model.table_exists?

          next if defined_model.name.include?("HABTM_")

          model = {
            TableName: defined_model.table_name,
            ModelName: defined_model.name,
            IsModelExist: true,
            Columns: []
          }

          next if defined_model.table_name.blank?

          foreign_keys = ::ActiveRecord::Schema.foreign_keys(defined_model.table_name).map { |k| k.options[:column] }
          primary_key = defined_model.primary_key

          defined_model.columns.each do |column|
            key = ""
            if column.name == primary_key
              key = "PK"
            elsif foreign_keys.include?(column.name)
              key = "FK"
            end
            model[:Columns] << {
              name: column.name,
              type: column.type,
              key: key,
              comment: column.comment
            }
          end

          result[:Models] << model

          next unless model[:IsModelExist]

          defined_model.reflect_on_all_associations(:has_many).each do |h|
            if h.options[:through]
              next
            end
            if h.options[:class_name]
              reverse_relation = result[:Relations].find { |r| r[:RightModelName] == model[:ModelName] && r[:LeftModelName] == h.options[:class_name] }
              if reverse_relation
                reverse_relation[:Comment] = if reverse_relation[:Comment] == ""
                  "has_many #{h.name}"
                else
                  "#{reverse_relation[:Comment]} : has_many #{h.name}"
                end
              else
                result[:Relations] << {
                  LeftModelName: model[:ModelName],
                  LeftValue: "||",
                  RightModelName: h.name.to_s.classify,
                  RightValue: "o{",
                  Comment: "has_many #{h.name}"
                }
              end
            else
              reverse_relation = result[:Relations].find { |r| r[:RightModelName] == model[:ModelName] && r[:LeftModelName] == h.name.to_s.classify }
              if reverse_relation
              else
                result[:Relations] << {
                  LeftModelName: model[:ModelName],
                  LeftValue: "||",
                  RightModelName: h.name.to_s.classify,
                  RightValue: "o{",
                  Comment: ""
                }
              end
            end
          end

          defined_model.reflect_on_all_associations(:has_and_belongs_to_many).each do |h|
            reverse_relation = if h.options[:class_name]
              result[:Relations].find { |r| r[:RightModelName] == model[:ModelName] && r[:LeftModelName] == h.options[:class_name] }
            else
              result[:Relations].find { |r| r[:RightModelName] == model[:ModelName] && r[:LeftModelName] == h.name.to_s.classify }
            end
            if reverse_relation
              reverse_relation[:Comment] = "HABTM"
            else
              result[:Relations] << {
                LeftModelName: model[:ModelName],
                LeftValue: "}o",
                RightModelName: h.name.to_s.classify,
                RightValue: "o{",
                Comment: "HABTM"
              }
            end
          end

          defined_model.reflect_on_all_associations(:belongs_to).each do |h|
            if h.options[:class_name]
              reverse_relation = result[:Relations].find { |r| r[:RightModelName] == model[:ModelName] && r[:LeftModelName] == h.options[:class_name] }

              if reverse_relation
                if (::Rails.application.config.active_record.belongs_to_required_by_default && h.options[:optional]) || (!::Rails.application.config.active_record.belongs_to_required_by_default && !h.options[:requried])
                  reverse_relation[:LeftValue] = "|o"
                end
                reverse_relation[:Comment] = if reverse_relation[:Comment] == ""
                  "belongs_to #{h.name}"
                else
                  "#{reverse_relation[:Comment]} : belongs_to #{h.name}"
                end
              else
                result[:Relations] << if (::Rails.application.config.active_record.belongs_to_required_by_default && h.options[:optional]) || (!::Rails.application.config.active_record.belongs_to_required_by_default && !h.options[:requried])
                  {
                    LeftModelName: model[:ModelName],
                    LeftValue: "}o",
                    RightModelName: h.options[:class_name],
                    RightValue: "o|",
                    Comment: "belongs_to #{h.name}"
                  }
                else
                  {
                    LeftModelName: model[:ModelName],
                    LeftValue: "}o",
                    RightModelName: h.options[:class_name],
                    RightValue: "||",
                    Comment: "belongs_to #{h.name}"
                  }
                end
              end
            else
              reverse_relation = result[:Relations].find { |r| r[:RightModelName] == model[:ModelName] && r[:LeftModelName] == h.name.to_s.classify }

              if reverse_relation
                if (::Rails.application.config.active_record.belongs_to_required_by_default && h.options[:optional]) || (!::Rails.application.config.active_record.belongs_to_required_by_default && !h.options[:requried])
                  reverse_relation[:LeftValue] = "|o"
                end
              else
                result[:Relations] << if (::Rails.application.config.active_record.belongs_to_required_by_default && h.options[:optional]) || (!::Rails.application.config.active_record.belongs_to_required_by_default && !h.options[:requried])
                  {
                    LeftModelName: model[:ModelName],
                    LeftValue: "}o",
                    RightModelName: h.name.to_s.classify,
                    RightValue: "o|",
                    Comment: ""
                  }
                else
                  {
                    LeftModelName: model[:ModelName],
                    LeftValue: "}o",
                    RightModelName: h.name.to_s.classify,
                    RightValue: "||",
                    Comment: ""
                  }
                end
              end
            end
          end

          defined_model.reflect_on_all_associations(:has_one).each do |h|
            if h.options[:class_name]
              reverse_relation = result[:Relations].find { |r| r[:RightModelName] == model[:ModelName] && r[:LeftModelName] == h.options[:class_name] }
              if reverse_relation
                reverse_relation[:LeftValue] = "|o"
                reverse_relation[:Comment] = if reverse_relation[:Comment] == ""
                  "has_one #{h.name}"
                else
                  "#{reverse_relation[:Comment]} : has_one #{h.name}"
                end

                if h.options[:through]
                  next
                end
              else
                result[:Relations] << {
                  LeftModelName: model[:ModelName],
                  LeftValue: "||",
                  RightModelName: h.options[:class_name],
                  RightValue: "o|",
                  Comment: "has_one #{h.name}"
                }
              end
            else
              reverse_relation = result[:Relations].find { |r| r[:RightModelName] == model[:ModelName] && r[:LeftModelName] == h.name.to_s.classify }
              if reverse_relation
                reverse_relation[:LeftValue] = "|o"
                if h.options[:through]
                  next
                end
              else
                result[:Relations] << {
                  LeftModelName: model[:ModelName],
                  LeftValue: "||",
                  RightModelName: h.name.to_s.classify,
                  RightValue: "o|",
                  Comment: "has_one #{h.name}"
                }
              end
            end
          end
        end

        result
      end
    end
  end
end
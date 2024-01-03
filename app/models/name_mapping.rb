# frozen_string_literal: true

# name mapping model
class NameMapping < ApplicationRecord
  validates :manually_created_name, presence: true, uniqueness: true
  validates :actual_name, presence: true

  def self.actual_name_of(name)
    name = filter_name(name)
    actual_name = NameMapping.where(manually_created_name: name)&.first
    return actual_name.actual_name unless actual_name.nil?
    name
  end

  def self.filter_name(name)
    name_ = name.downcase.gsub(/\(paeds\)/, '').strip
    name_ = name_.downcase.gsub(/\(cancercenter\)/, '').strip
    name_ = name_.gsub("_"," ")
    name_
  end
end

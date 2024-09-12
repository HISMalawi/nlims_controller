# frozen_string_literal

# Patient model
class Patient < ApplicationRecord
  def first_name
    name.split(' ').first
  end

  def last_name
    name.split(' ').last
  end

  def middle_name
    name.split(' ').length > 2 ? name.split(' ')[1] : ''
  end

  def sex
    gender == 'F' ? 1 : 0
  end
end

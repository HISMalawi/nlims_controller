# frozen_string_literal: true

# Central Specimen ID Generator Service
module CsigService
  def self.generate_ids
    return ids if ids.present?
  end

  # Convert a number to base 9
  def self.convert_to_base9(number)
    return number if number < 9

    result = ''
    while number != 0
      result = (number % 9).to_s + result
      number /= 9
    end
    result.to_i
  end

  # Prepad a number with 0s to a given length
  def self.prepad_number_with_zeros(length = 10, number)
    number.to_s.rjust(length, '0')
  end

  def self.concat_check_digit_with_seq_number(check_digit, seq_number)
    (check_digit.to_s + seq_number.to_s).to_i
  end
end

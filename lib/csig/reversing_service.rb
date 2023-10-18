# frozen_string_literal: true

require 'csig/csig_utility_service'

# Reversing Service for Central Specimen ID Generator - Reverses sin back to seq number
module ReversingService
  # Remove check digit from a sin
  def self.remove_check_digit(sin)
    sin.to_s[2..-1]
  end

  # reverse clean zeros by subtracting 1 from each individual value in the number
  def self.reverse_zero_cleaned(number)
    numbers = number.to_i.digits.reverse
    numbers.map { |n| n - 1 }.join.to_i
  end

  # convert base 9 number to base 10
  def self.convert_to_base10(number)
    number.to_s.to_i(9)
  end

  # Reverse the sin to sequence number
  def self.reverse_sin_to_seq(sin)
    sin_without_check_digit = remove_check_digit(sin.to_s)
    encrypted_sin = reverse_zero_cleaned(sin_without_check_digit)
    decrypted_sin = CsigUtilityService.decrypt(encrypted_sin)
    convert_to_base10(decrypted_sin)
  end
end

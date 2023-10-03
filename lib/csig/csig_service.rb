# frozen_string_literal: true

require 'csig/fpe_service'
# Central Specimen ID Generator Service
module CsigService
  def self.generate_ids
    return ids if ids.present?
  end

  # Encrypt a number using FPE FF3
  def self.encrypt(plaintext)
    encryption_key = '3a12f03a59b73e5e06f6c5babb22d76203e177a8b87f274a'
    tweak_value = '0123456789ABCDEF'
    radix = 10
    ff3 = FF3Cipher.new(encryption_key, tweak_value, radix)
    ff3.encrypt(plaintext.to_s)
  end

  # Decrypt a ciphernumber using FPE FF3
  def self.decrypt(ciphertext)
    encryption_key = '3a12f03a59b73e5e06f6c5babb22d76203e177a8b87f274a'
    tweak_value = '0123456789ABCDEF'
    radix = 10
    ff3 = FF3Cipher.new(encryption_key, tweak_value, radix)
    ff3.decrypt(ciphertext)
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

  def self.concat_check_digit_with_number(check_digit, number)
    (check_digit.to_s + number.to_s).to_i
  end
end

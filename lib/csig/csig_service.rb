# frozen_string_literal: true

require 'csig/fpe_service'
require 'csig/mod9710_service'
# Central Specimen ID Generator Service
module CsigService
  def self.generate_sin(number_of_ids = 100)
    last_id = SpecimenIdentification.last
    last_id = last_id.nil? ? 1 : last_id.id
    0..number_of_ids.times do
      sequence_number = last_id
      base9_equivalent = convert_to_base9(sequence_number)
      base9_equivalent_zero_padded = prepad_number_with_zeros(10, base9_equivalent)
      fp_encrypted = encrypt(base9_equivalent_zero_padded)
      fp_encrypted_zero_cleaned = zero_cleaned(fp_encrypted)
      check_digit = Mod9710Service.calculate_check_digit(fp_encrypted_zero_cleaned)
      sin = concat_check_digit_with_number(check_digit, fp_encrypted_zero_cleaned)
      SpecimenIdentification.create(
        sequence_number: sequence_number,
        base9_equivalent: base9_equivalent,
        base9_zero_padded: base9_equivalent_zero_padded,
        encrypted: fp_encrypted,
        encrypted_zero_cleaned: fp_encrypted_zero_cleaned,
        check_digit: check_digit,
        sin: sin
      )
      last_id += 1
    end
    consective_last_id = last_id + 1
    SpecimenIdentification.where(id: consective_last_id..(consective_last_id + number_of_ids))
  end

  # Encrypt a number using FPE FF3
  def self.encrypt(plaintext)
    encryption_key = '3a12f03a59b73e5e06f6c5babb22d76203e177a8b87f274a'
    tweak_value = '0123456789ABCDEF'
    radix = 9
    alphabet = '012345678'
    ff3 = FF3Cipher.new(encryption_key, tweak_value, radix, alphabet)
    ff3.encrypt(plaintext.to_s)
  end

  # Decrypt a ciphernumber using FPE FF3
  def self.decrypt(ciphertext)
    encryption_key = '3a12f03a59b73e5e06f6c5babb22d76203e177a8b87f274a'
    tweak_value = '0123456789ABCDEF'
    radix = 9
    alphabet = '012345678'
    ff3 = FF3Cipher.new(encryption_key, tweak_value, radix, alphabet)
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
    check_digit.to_s + number.to_s
  end

  # clean zeros by adding 1 to each individual value in the number
  def self.zero_cleaned(number)
    numbers = number.to_i.digits.reverse
    numbers.map { |n| n + 1 }.join.to_i
  end
end

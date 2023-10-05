# frozen_string_literal: true

# module Mod9710Service for generating and validating numbers using mod 97
# See https://en.wikipedia.org/wiki/International_Bank_Account_Number#Modulo_operation_on_IBAN
# for more information about mod 97
# see https://www.govinfo.gov/content/pkg/CFR-2016-title12-vol8/xml/CFR-2016-title12-vol8-part1003-appC.xml
module Mod9710Service
  def self.mod97(number)
    (number.to_s << '00').to_i % 97
  end

  def self.calculate_check_digit(number)
    format('%02d', (98 - mod97(number)))
  end

  def self.validate_number(number)
    number % 97 == 1
  end
end

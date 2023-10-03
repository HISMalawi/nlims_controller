# SPDX-Copyright: Copyright (c) Schoening Consulting, LLC
# SPDX-License-Identifier: Apache-2.0
# Copyright 2021 Schoening Consulting, LLC

# SPDX-Copyright: Copyright (c) EGPAF Malawi
# SPDX-License-Identifier: Apache-2.0
# Copyright 2023 EGPAF Malawi

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and limitations under
# the License.

require 'openssl'

NUM_ROUNDS = 8
BLOCK_SIZE = 16 # aes.BlockSize
TWEAK_LEN = 8 # Original FF3 tweak length
TWEAK_LEN_NEW = 7 # FF3-1 tweak length
HALF_TWEAK_LEN = (TWEAK_LEN / 2).to_i
MAX_RADIX = 256
DOMAIN_MIN = 1_000_000

# FF3_1 Cipher class
class FF3Cipher
  def initialize(key, tweak, radix=10, alphabet='0123456789')
    keybytes = [key].pack('H*')
    @alphabet = alphabet
    @tweak = tweak
    @radix = radix
    @min_len = (Math.log(DOMAIN_MIN) / Math.log(radix)).ceil
    @max_len = (2 * (96 / Math.log(2, radix))).floor
    keylength = keybytes.length
    algo = algorithm(keylength)
    raise 'radix must be between 2 and 62, inclusive' if radix < 2 || radix > MAX_RADIX

    raise 'min_len or max_len is invalid, adjust radix' if @min_len < 2 || @max_len < @min_len

    @cipher = OpenSSL::Cipher.new(algo)
    @cipher.key = reversed(keybytes)
    @cipher
  end

  def encrypt(plaintext)
    tweak_bytes = [@tweak].pack('H*')
    plaintext_len = plaintext.length
    raise "plaintext must be between #{@min_len} and #{@max_len} digits" if plaintext_len < @min_len || plaintext_len > @max_len

    raise "tweak must be #{TWEAK_LEN} bytes" unless [TWEAK_LEN, TWEAK_LEN_NEW].include?(tweak_bytes.length)

    split_point_u = (plaintext_len / 2.0).ceil
    split_point_v = plaintext_len - split_point_u
    plaintext_a = plaintext[0..(split_point_u - 1)]
    plaintext_b = plaintext[split_point_u..-1]
    tweak_bytes = calculate_tweak64_ff3_1(tweak_bytes) if tweak_bytes.length == TWEAK_LEN_NEW
    tweak_a = tweak_bytes[0..(HALF_TWEAK_LEN - 1)]
    tweak_b = tweak_bytes[HALF_TWEAK_LEN..-1]
    mod_split_point_u = @radix**split_point_u
    mod_split_point_v = @radix**split_point_v

    0..NUM_ROUNDS.times do |i|
      if (i % 2).zero?
        m = split_point_u
        wx = tweak_b
      else
        m = split_point_v
        wx = tweak_a
      end
      px = calculate_p(i, @alphabet, wx, plaintext_b)
      reverse_px = px.map(&:reverse)
      @cipher.encrypt
      ciphertext = @cipher.update(reverse_px.first)
      ciphertext << @cipher.final
      ciphertext_reverse = reversed(ciphertext)
      y = ciphertext_reverse.unpack('Q>').first
      c = decode_int_to_str(plaintext_a, @alphabet)
      c += y
      c = if (i % 2).zero?
            (c % mod_split_point_u).to_s
          else
            (c % mod_split_point_v).to_s
          end
      cx = encode_int_to_str(c, @alphabet, m.to_i)
      plaintext_a = plaintext_b
      plaintext_b = cx
    end
    plaintext_a + plaintext_b
  end

  def decrypt(ciphertext)
    tweak_bytes = [@tweak].pack('H*')
    ciphertext_len = ciphertext.length
    raise "ciphertext must be between #{@min_len} and #{@max_len} digits" if ciphertext_len < @min_len || ciphertext_len > @max_len

    raise "tweak must be #{TWEAK_LEN} bytes" unless [TWEAK_LEN, TWEAK_LEN_NEW].include?(tweak_bytes.length)

    split_point_u = (ciphertext_len / 2.0).ceil
    split_point_v = ciphertext_len - split_point_u
    ciphertext_a = ciphertext[0..(split_point_u - 1)]
    ciphertext_b = ciphertext[split_point_u..-1]
    tweak_bytes = calculate_tweak64_ff3_1(tweak_bytes) if tweak_bytes.length == TWEAK_LEN_NEW
    tweak_a = tweak_bytes[0..(HALF_TWEAK_LEN - 1)]
    tweak_b = tweak_bytes[HALF_TWEAK_LEN..-1]
    mod_split_point_u = @radix**split_point_u
    mod_split_point_v = @radix**split_point_v
    (NUM_ROUNDS - 1).downto(0) do |i|
      if (i % 2).zero?
        m = split_point_u
        wx = tweak_b
      else
        m = split_point_v
        wx = tweak_a
      end
      px = calculate_p(i, @alphabet, wx, ciphertext_a)
      reverse_px = px.map(&:reverse)
      @cipher.encrypt
      ciphertext = @cipher.update(reverse_px.first)
      ciphertext << @cipher.final
      ciphertext_reverse = reversed(ciphertext)
      y = ciphertext_reverse.unpack('Q>').first
      c = decode_int_to_str(ciphertext_b, @alphabet)
      c -= y
      c = if (i % 2).zero?
            (c % mod_split_point_u).to_s
          else
            (c % mod_split_point_v).to_s
          end
      cx = encode_int_to_str(c, @alphabet, m.to_i)
      ciphertext_b = ciphertext_a
      ciphertext_a = cx
    end
    ciphertext_a + ciphertext_b
  end
end

def algorithm(keylength)
  algo = 'unknown'
  case keylength
  when 16
    algo = 'AES-128-ECB'
  when 24
    algo = 'AES-192-ECB'
  when 32
    algo = 'AES-256-ECB'
  else
    raise "key length #{keylength} must be 128,192 or 256 bits"
  end
  algo
end

def reversed(str)
  str.reverse!
end

def decode_int_to_str(str, alphabet)
  strlen = str.length
  base = alphabet.length
  num = 0
  count = 0
  str = str.reverse
  begin
    str.each_char do |char|
      power = strlen - (count + 1)
      l = alphabet.index(char).nil? ? 0 : alphabet.index(char)
      num += l * (base**power)
      count += 1
    end
  rescue StandardError => e
    e.message
  end
  num
end

def encode_int_to_str(num, alphabet, len = 0)
  base = alphabet.length
  raise ArgumentError, "RADIX must be less than #{MAX_RADIX}" if base > MAX_RADIX

  num = num.to_i
  str_x = ''
  while num >= base
    num, b = num.divmod(base)
    str_x += alphabet[b]
  end
  str_x += alphabet[num]
  str_x = str_x.ljust(len, alphabet[0]) if str_x.length < len
  str_x
end

def calculate_p(i, alphabet, wx, bx)
  px = [0] * 16
  px[0] = wx[0]
  px[1] = wx[1]
  px[2] = wx[2]
  px[3] = wx[3].nil? ? wx[3] ^ i.to_i : (wx[3].ord ^ i.to_i).chr
  bx_bytes = int_to_bytes_str(decode_int_to_str(bx, alphabet))
  px[(BLOCK_SIZE - bx_bytes.length)..-1] = bx_bytes
  px
end

def int_to_bytes_str(n)
  bytes = [n].pack('Q>').bytes
  bytes.map { |byte| "\\x#{byte.to_s(16).rjust(2, '0')}" }.join('')
end

def calculate_tweak64_ff3_1(tweak56)
  tweak64 = [0] * 8
  tweak64[0] = tweak56[0]
  tweak64[1] = tweak56[1]
  tweak64[2] = tweak56[2]
  tweak64[3] = (tweak56[3].ord & 0xF0).chr
  tweak64[4] = tweak56[4]
  tweak64[5] = tweak56[5]
  tweak64[6] = tweak56[6]
  tweak64[7] = (tweak56[3].ord & 0x0F).chr << 4
  tweak64
end

# USAGE
plaintext = 3_992_520_240
cipher = FF3Cipher.new('3a12f03a59b73e5e06f6c5babb22d76203e177a8b87f274a', '0123456789ABCDEF', 10, '0123456789')
c = cipher.encrypt(plaintext.to_s)
d = cipher.decrypt(c)
puts "plaintext: #{plaintext}"
puts "ciphertext: #{c}"
puts "decrypted text: #{d}"

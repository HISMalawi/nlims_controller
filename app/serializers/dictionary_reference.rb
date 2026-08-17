# frozen_string_literal: true

# How a transactional record points at a dictionary entry.
#
# The national code is the address — the same one the client sent when it
# ordered the test, and the only one that means anything on another node. The
# uuid rides along so a client that stores uuids can match without a lookup, and
# the name so that a log or a screen is readable without joining the dictionary.
class DictionaryReference
  def self.call(entry)
    return if entry.nil?

    {
      uuid: entry.uuid,
      national_code: entry.national_code,
      name: entry.name
    }
  end
end

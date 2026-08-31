# frozen_string_literal: true

# How a transactional record points at a clinical term.
#
# The national code is the address — the same one the client sent when it
# ordered the test, and the only one that means anything on another node. The
# uuid rides along so a client that stores uuids can match without a lookup, and
# the name so that a log or a screen is readable without joining the dictionary.
#
# All three may now be partly absent. A term this node's dictionary does not
# carry has a name and, sometimes, the code it was ordered under, but no uuid:
# there is nothing here for a uuid to point at. That is the shape a client has
# to expect while the national catalogue is being assembled — the name is what
# is always there, and the name is what the laboratory works from.
class DictionaryReference
  def self.call(term)
    case term
    when nil then nil
    when Dictionary::Reference then term.as_json
    else { uuid: term.uuid, national_code: term.national_code, name: term.name }
    end
  end
end

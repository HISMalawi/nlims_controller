# frozen_string_literal: true

# Some endpoints only exist on one kind of node, and the routes are drawn at
# boot from SISLAB_SYNC_MODE, so the mode cannot be changed mid-suite. Specs for
# those endpoints declare which node they belong to and are skipped on the
# other, where the whole suite runs twice:
#
#   RSpec.describe "...", type: :request, mode: :local do
RSpec.configure do |config|
  config.before(:each, mode: :local) do
    skip "these endpoints only exist on a local node" unless SislabSync.local?
  end

  config.before(:each, mode: :national) do
    skip "these endpoints only exist on the national node" unless SislabSync.national?
  end
end

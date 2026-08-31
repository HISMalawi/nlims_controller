# frozen_string_literal: true

# Who is out there and who has gone quiet. The national node only — a local node
# knows about exactly one other node, and the dashboard already says whether it
# is reaching it.
class NodesController < ApplicationController
  def index
    @nodes = Node.order(Arel.sql("last_seen_at IS NULL DESC, last_seen_at ASC"))
    @cursor = Dictionary.cursor
    @stale = Node.stale.count
  end
end

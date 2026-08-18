# frozen_string_literal: true

# The API reference, served by the node it describes.
#
# Open to anyone who can reach the node, and deliberately so: it is what a team
# integrating reads before they have a key, and asking for a key in order to
# find out how to ask for a key is the loop this replaces. There is nothing
# here that is not already in the repository.
#
# The machine-readable document is the same file the suite validates every
# response against, narrowed to this node — so a reference that is out of date
# is a build that is red, not a page nobody noticed.
class ApiDocsController < ApplicationController
  allow_unauthenticated_access

  def show
    @document = ApiContract.this_node

    respond_to do |format|
      format.html do
        status, headers, body = Scalar::UI.call(request.env)
        response.status = status
        response.headers.merge!(headers)
        self.response_body = body
      end
      format.json { render json: @document }
      format.yaml { render plain: @document.to_yaml, content_type: "application/yaml" }
    end
  end
end

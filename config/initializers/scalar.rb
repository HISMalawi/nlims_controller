# frozen_string_literal: true

Scalar.setup do |config|
  config.page_title = "SISLAB Sync · Referência da API"
  config.configuration = {
    url: "/api-docs.json",
    theme: "saturn",
    layout: "modern",
    showSidebar: true,
    searchHotKey: "k"
  }
end

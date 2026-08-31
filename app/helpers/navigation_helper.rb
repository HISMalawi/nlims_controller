# frozen_string_literal: true

# What the sidebar offers. Kept here rather than in the layout so that "which
# screens does an operator on a local node actually see" is one readable list
# and one spec, instead of a dozen conditionals scattered through markup.
module NavigationHelper
  # The path is a block rather than a string because the routes for the
  # mode-specific screens are only drawn in that mode: calling `sync_queue_path`
  # on the national node would raise while building a list that was about to
  # discard it anyway.
  Item = Struct.new(:key, :to, :admin_only, :modes, keyword_init: true) do
    def visible_to?(user)
      return false if admin_only && !user&.admin?

      modes.blank? || modes.include?(SislabSync.mode)
    end
  end

  def navigation_items
    [
      Item.new(key: :dashboard, to: -> { root_path }),
      Item.new(key: :orders, to: -> { orders_path }),
      Item.new(key: :referrals, to: -> { referrals_path }),
      Item.new(key: :dictionary, to: -> { dictionary_path }),
      Item.new(key: :sync_queue, to: -> { sync_queue_path }, modes: %w[local]),
      Item.new(key: :nodes, to: -> { nodes_path }, modes: %w[national]),
      Item.new(key: :api_clients, to: -> { api_clients_path }, admin_only: true),
      Item.new(key: :audits, to: -> { audits_path }, admin_only: true)
    ].select { |item| item.visible_to?(current_user) }
  end

  def nav_link_to(item)
    path = item.to.call

    classes = if current_page?(path) || request.path.start_with?("#{path}/")
      "bg-slate-800 text-white"
    else
      "text-slate-300 hover:bg-slate-800/60 hover:text-white"
    end

    link_to t("nav.#{item.key}"), path,
            class: "block rounded-md px-3 py-2 text-sm font-medium transition #{classes}"
  end
end

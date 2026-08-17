# frozen_string_literal: true

# What the sidebar offers. Kept here rather than in the layout so that "which
# screens does an operator on a local node actually see" is one readable list
# and one spec, instead of a dozen conditionals scattered through markup.
module NavigationHelper
  Item = Struct.new(:key, :path, :admin_only, :modes, keyword_init: true) do
    def visible_to?(user)
      return false if admin_only && !user&.admin?

      modes.blank? || modes.include?(SislabSync.mode)
    end
  end

  def navigation_items
    [
      Item.new(key: :dashboard, path: root_path),
      Item.new(key: :orders, path: orders_path),
      Item.new(key: :referrals, path: referrals_path)
    ].select { |item| item.visible_to?(current_user) }
  end

  def nav_link_to(item)
    classes = if current_page?(item.path) || request.path.start_with?("#{item.path}/")
      "bg-slate-800 text-white"
    else
      "text-slate-300 hover:bg-slate-800/60 hover:text-white"
    end

    link_to t("nav.#{item.key}"), item.path,
            class: "block rounded-md px-3 py-2 text-sm font-medium transition #{classes}"
  end
end

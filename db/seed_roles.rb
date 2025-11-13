# frozen_string_literal: true

# seed roles
roles = %w[
  admin
  system
  test_catalog_manager
  test_catalog_viewer
  test_catalog_approver
  test_catalog_releaser
]

roles.each do |role_name|
  Role.find_or_create_by!(name: role_name)
end

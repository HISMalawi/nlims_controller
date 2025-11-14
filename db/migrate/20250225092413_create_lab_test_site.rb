# frozen_string_literal: true

# This migration creates the lab_test_sites table.
class CreateLabTestSite < ActiveRecord::Migration[7.1]
  def change
    create_table :lab_test_sites do |t|
      t.string :name
      t.text :description
      t.timestamps
    end

    lab_test_sites_data = [
      { name: 'Community Setting',
        description: 'A setting where health services are provided in the community, often with limited diagnostic capabilities.' },
      { name: 'Primary health facilities without laboratories',
        description: 'Basic health facilities that provide primary care but do not have laboratory services for diagnostic testing.' },
      { name: 'Primary health facilities with clinical laboratories (including urban health centres)',
        description: 'Primary care health facilities equipped with clinical laboratories, including urban health centres that provide diagnostic testing services.' },
      { name: 'Secondary level health facilities (including community hospitals)',
        description: 'Health facilities providing specialized care and diagnostic services, including community hospitals offering more advanced medical services.' },
      { name: 'Tertiary level health facilities',
        description: 'Advanced healthcare facilities offering specialized treatment, surgeries, and diagnostic testing, typically located in larger urban areas.' },
      { name: 'National public health reference laboratory',
        description: 'A national laboratory focused on public health surveillance, providing reference testing and supporting national health programs.' }
    ]

    # Inserting the data
    lab_test_sites_data.each do |data|
      execute <<-SQL
        INSERT INTO lab_test_sites (name, description, created_at, updated_at)
        VALUES ('#{data[:name]}', '#{data[:description]}', NOW(), NOW())
      SQL
    end
  end
end

# frozen_string_literal: true

require 'roo'
# module Test Catalog Management
module TestCatalogManagement
  # Test Catalog Service
  class TestCatalogVersionManager
    def self.get_test_catalog
      catalog = TestCatalogVersion.last&.catalog || {}
      ProcessTestCatalogService.process_test_catalog(catalog.deep_symbolize_keys)
      {
        specimen_types: SpecimenType.all.as_json({ context: :single_item }),
        drugs: Drug.all.as_json,
        organisms: Organism.all.as_json({ context: :single_item }),
        test_types: TestType.all.as_json({ context: :single_item }),
        test_panels: PanelType.all.as_json,
        departments: TestCategory.all.as_json
      }
    end

    def self.release_version(version_details)
      TestCatalogVersion.create!(
        catalog: get_test_catalog,
        creator: User.current&.id,
        version_details:,
        status: 'approved-release'
      )
    end

    def self.approve_version(version)
      TestCatalogVersion.find_by(version:).update(
        status: 'approved-release',
        approved_by: User.current&.id,
        approved_at: Time.now
      )
    end

    def self.reject_version(version, reason)
      TestCatalogVersion.find_by(version:).update(
        status: 'rejected',
        rejection_reason: reason,
        rejected_by: User.current&.id,
        rejected_at: Time.now
      )
    end

    def self.retrieve_test_catalog(version)
      if version.present?
        TestCatalogVersion.find_by(version:) || {}
      else
        TestCatalogVersion.last || {}
      end
    end

    def self.test_catalog_versions
      TestCatalogVersion.where(status: 'approved-release').select(:id, :version, :created_at).order(created_at: :desc)
    end

    def self.new_version_available?(previous_version)
      catalog_version = TestCatalogVersion.where(status: 'approved-release')
                                          .select(:id, :version, :version_details, :created_at)
                                          .order(created_at: :desc)
      latest_version = catalog_version.pick(:version)
      version_details = catalog_version.pick(:version_details)
      return { is_new_version_available: false, version: latest_version } unless latest_version.present?

      {
        is_new_version_available: latest_version.gsub('v', '').to_i > previous_version.gsub('v', '').to_i,
        version: latest_version,
        version_details: version_details
      }
    end

    def self.generate_json(version)
      catalog = retrieve_test_catalog(version)
      File.write(
        'test_catalog_version.json',
        JSON.pretty_generate(
          catalog.as_json(
            except: %i[status approved_by rejected_by approved_at rejected_at rejection_reason]
          )
        )
      )
    end

    def self.download_test_catalog(version)
      catalog = retrieve_test_catalog(version)
      send_data(catalog.catalog.to_json, filename: "test_catalog_v#{catalog.version}.json")
    end
  end
end

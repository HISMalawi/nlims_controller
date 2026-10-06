# frozen_string_literal: true

# A central EMR deployment (e.g. MaHIS) that master NLIMS talks to directly for sites
# that have been migrated off a local NLIMS.
class EmrInstance < ApplicationRecord
  EMR_TYPES = { 'mahis_central' => 'MaHIS (central)' }.freeze
  URL_FORMAT = %r{\Ahttps?://[^\s/]+(:\d+)?(/[^\s]*)?\z}

  encrypts :password
  has_paper_trail skip: %i[password]

  has_many :sites, dependent: :restrict_with_error

  before_validation :normalize_urls

  validates :name, presence: true, uniqueness: true
  validates :emr_type, inclusion: { in: EMR_TYPES.keys }
  validates :base_url, presence: true, format: { with: URL_FORMAT, message: 'must be a valid http(s) URL' }
  validates :health_path, :login_path, :summary_path, presence: true
  validates :timeout_seconds, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 120 }
  # Concept ids differ between the central EMR and local EMRs, so there is no safe default
  validates :vl_concept_id, presence: true, numericality: { only_integer: true, greater_than: 0 }

  scope :active, -> { where(active: true) }

  def url_for(path)
    "#{base_url}/#{path.to_s.delete_prefix('/')}"
  end

  def host
    URI.parse(base_url).host
  rescue URI::InvalidURIError
    base_url
  end

  def port
    URI.parse(base_url).port
  rescue URI::InvalidURIError
    nil
  end

  private

  def normalize_urls
    self.base_url = base_url.to_s.strip.delete_suffix('/') if base_url.present?
    %i[health_path version_path login_path summary_path].each do |attr|
      value = self[attr].to_s.strip
      self[attr] = value.blank? ? nil : "/#{value.delete_prefix('/')}"
    end
  end
end

# frozen_string_literal: true

# TrackingNumber module
module TrackingNumberService
  DAY_MAPPING = {
    '01' => '1', '02' => '2', '03' => '3', '04' => '4', '05' => '5',
    '06' => '6', '07' => '7', '08' => '8', '09' => '9', '10' => 'A',
    '11' => 'B', '12' => 'C', '13' => 'E', '14' => 'F', '15' => 'G',
    '16' => 'H', '17' => 'Y', '18' => 'J', '19' => 'K', '20' => 'Z',
    '21' => 'M', '22' => 'N', '23' => 'O', '24' => 'P', '25' => 'Q',
    '26' => 'R', '27' => 'S', '28' => 'T', '29' => 'V', '30' => 'W',
    '31' => 'X'
  }.freeze

  def self.convert_day(day)
    DAY_MAPPING[day]
  end

  # rubocop:disable Metrics/MethodLength,Lint/MissingCopEnableDirective
  # rubocop:disable Metrics/AbcSize
  def self.generate_tracking_number
    configs = YAML.load_file "#{Rails.root}/config/application.yml"
    site_code = configs['facility_code']
    todate = Time.now.strftime('%Y%m%d')
    year = Time.now.strftime('%y')
    month = Time.now.strftime('%m')
    day = Time.now.strftime('%d')
    last_tracking_number_trail = TrackingNumberTrail.last
    date = last_tracking_number_trail&.date || todate
    current_value = last_tracking_number_trail&.current_value || 3500
    value = todate.to_i > date.to_i ? prepad_str(1, 3) : prepad_str(current_value.to_i + 1, 3)
    tracking_number = "X#{site_code}#{year}#{get_month(month)}#{get_day(day)}NL#{value}"
    TrackingNumberTrail.create(date: todate, current_value: value.to_i)
    tracking_number
  end

  def self.get_month(month)
    convert_day(month)
  end

  def self.get_day(day)
    convert_day(day)
  end

  def self.prepad_str(str, padding)
    str.to_s.rjust(padding, '0').to_s
  end
end

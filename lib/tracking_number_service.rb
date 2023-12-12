# frozen_string_literal: true

# TrackingNumber module
module TrackingNumberService
	DAY_MAPPING = {
    "01" => "1", "02" => "2", "03" => "3", "04" => "4", "05" => "5",
    "06" => "6", "07" => "7", "08" => "8", "09" => "9", "10" => "A",
    "11" => "B", "12" => "C", "13" => "E", "14" => "F", "15" => "G",
    "16" => "H", "17" => "Y", "18" => "J", "19" => "K", "20" => "Z",
    "21" => "M", "22" => "N", "23" => "O", "24" => "P", "25" => "Q",
    "26" => "R", "27" => "S", "28" => "T", "29" => "V", "30" => "W",
    "31" => "X"
  }.freeze

  def self.convert_day(day)
    DAY_MAPPING[day]
  end

	def self.generate_tracking_number
		configs = YAML.load_file "#{Rails.root}/config/application.yml"
		site_code = configs['facility_code']
		file = JSON.parse(File.read("#{Rails.root}/public/tracker.json"))
		todate = Time.now.strftime("%Y%m%d")
		year = Time.now.strftime("%Y%m%d").to_s.slice(2..3)
		month = Time.now.strftime("%m")
		day = Time.now.strftime("%d")
	
		key = file.keys
		
		if todate > key[0]

			fi = {}
			fi[todate] = 1
			File.open("#{Rails.root}/public/tracker.json", 'w') {|f|
					
	    	     	f.write(fi.to_json) } 

	    	 value =  "001"
	    	 tracking_number = "X" + site_code + year.to_s +  get_month(month).to_s +  get_day(day).to_s + value.to_s
			
		else
			counter = file[todate]

			if counter.to_s.length == 1
				
				value = "00" + counter.to_s
			elsif counter.to_s.length == 2
				
				value = "0" + counter.to_s
			else
				value = counter.to_s
			end
			

			tracking_number = "X" + site_code + year.to_s +  get_month(month).to_s +  get_day(day).to_s + value.to_s
			
		end
		return tracking_number
	end

	def self.prepare_next_tracking_number
			file = JSON.parse(File.read("#{Rails.root}/public/tracker.json"))
			todate = Time.now.strftime("%Y%m%d")
				
			counter = file[todate]
			counter = counter.to_i + 1
			fi = {}
			fi[todate] = counter
			File.open("#{Rails.root}/public/tracker.json", 'w') {|f|
					
	    	     	f.write(fi.to_json) } 	
	end

	def self.get_month(month)
		convert_day(month)
	end

	def self.get_day(day)
		convert_day(day)
	end
end

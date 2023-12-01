module TrackingNumberService
	

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
			

			tracking_number = "X" + site_code + year.to_s +  get_month(month).to_s +  get_day(day).to_s + 'NL' + value.to_s
			
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
		
		case month

			when "01"
				return "1"
			when "02"
				return "2"
			when "03"
				return "3"
			when "04"
				return "4"
			when "05"
				return "5"
			when "06"
				return "6"
			when "07"
				return "7"
			when "08"
				return "8"
			when "09"
				return "9"
			when "10"
				return "A"
			when "11"
				return "B"
			when "12"
				return "C"
			end

	end

	def self.get_day(day)

		case day

			when "01"
				return "1"
			when "02"
				return "2"
			when "03"
				return "3"
			when "04"
				return "4"
			when "05"
				return "5"
			when "06"
				return "6"
			when "07"
				return "7"
			when "08"
				return "8"
			when "09"
				return "9"
			when "10"
				return "A"
			when "11"
				return "B"
			when "12"
				return "C"
			when "13"
				return "E"
			when "14"
				return "F"
			when "15"
				return "G"
			when "16"
				return "H"
			when "17"
				return "Y"
			when "18"
				return "J"
			when "19"
				return "K"
			when "20"
				return "Z"
			when "21"
				return "M"
			when "22"
				return "N"
			when "23"
				return "O"
			when "24"
				return "P"
			when "25"
				return "Q"
			when "26"
				return "R"
			when "27"
				return "S"
			when "28"
				return "T"
			when "29"
				return "V"
			when "30"
				return "W"
			when "31"
				return "X"
			end	

	end


end

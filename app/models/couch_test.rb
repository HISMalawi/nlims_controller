class CouchTest < CouchRest::Model::Base
	use_database 'test'

	property :order_id, String
	property :test_type_id, String
	property :time_created, String
	property :test_status_id, String

end

# frozen_string_literal: true

require 'cgi'
require 'rest-client'

module MahisCouchdb
  # Tiny CouchDB HTTP client used by the NLiMS/MaHIS patient-record bridge.
  class Client
    attr_reader :config, :database

    def initialize(config = Configuration.current, database: nil)
      @config = config
      @database = database.presence || config.database
    end

    def enabled?
      config.enabled?
    end

    def changes(since:, limit: nil)
      get('_changes', query: {
            since: since.presence || config.initial_since,
            include_docs: true,
            limit: limit || config.changes_limit
          })
    end

    def get_doc(id)
      get(encoded_doc_id(id))
    end

    def put_doc(doc)
      raise ArgumentError, 'CouchDB document _id missing' if doc['_id'].blank?

      put(encoded_doc_id(doc['_id']), doc)
    end

    def find(selector, limit: 1, bookmark: nil, fields: nil)
      payload = { selector:, limit: }
      payload[:bookmark] = bookmark if bookmark.present?
      payload[:fields] = fields if fields.present?
      post('_find', payload)
    end

    def create_index(fields:, name:, ddoc: nil)
      payload = {
        index: { fields: },
        name:,
        type: 'json'
      }
      payload[:ddoc] = ddoc if ddoc.present?
      post('_index', payload)
    end

    def changes_feed_url(query = {})
      build_url('_changes', query)
    end

    private

    def get(path, query: {})
      request(:get, path, query:)
    end

    def post(path, payload)
      request(:post, path, payload:)
    end

    def put(path, payload)
      request(:put, path, payload:)
    end

    def request(method, path, payload: nil, query: {})
      options = {
        method:,
        url: build_url(path, query),
        headers: { accept: :json, content_type: :json },
        timeout: config.timeout,
        open_timeout: config.open_timeout
      }
      options[:payload] = payload.to_json if payload
      options[:user] = config.username if config.username
      options[:password] = config.password if config.password

      response = RestClient::Request.execute(options)
      response.body.present? ? JSON.parse(response.body) : {}
    end

    def build_url(path, query = {})
      url = "#{database_url}/#{path.to_s.sub(%r{\A/+}, '')}"
      query = query.compact_blank
      return url if query.blank?

      "#{url}?#{URI.encode_www_form(query)}"
    end

    def database_url
      "#{config.base_url.sub(%r{/+\z}, '')}/#{CGI.escape(database)}"
    end

    def encoded_doc_id(id)
      id.to_s.split('/').map { |part| CGI.escape(part) }.join('/')
    end
  end
end

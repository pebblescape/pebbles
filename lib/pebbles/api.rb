require "base64"
require "cgi"
require "excon"
require "multi_json"
require "securerandom"
require "uri"
require "zlib"

require "pebbles/command"
require "pebbles/api/errors"
require "pebbles/api/apps"
require "pebbles/api/login"
require "pebbles/api/user"

module Pebbles
  class API
    HEADERS = {
      'Accept'                => 'application/vnd.pebblescape+json; version=1',
      'Accept-Encoding'       => 'gzip',
      #'Accept-Language'       => 'en-US, en;q=0.8',
      'User-Agent'            => Pebbles.user_agent,
      'X-Ruby-Version'        => RUBY_VERSION,
      'X-Ruby-Platform'       => RUBY_PLATFORM
    }
    
    OPTIONS = {
      :headers  => {},
      :host     => 'api.pebblesinspace.com',
      :nonblock => false,
      :scheme   => 'https'
    }
    
    def initialize(options={})
      options = OPTIONS.merge(options)
      options[:headers] = HEADERS.merge(options[:headers])

      @api_key = options.delete(:api_key) || ENV['PEBBLES_API_KEY']
      if !@api_key && options.has_key?(:username) && options.has_key?(:password)
        username = options.delete(:username)
        password = options.delete(:password)
        @connection = Excon.new("#{options[:scheme]}://#{options[:host]}", options)
        @api_key = self.post_login(username, password).body["api_key"]
      end

      @connection = Excon.new("#{options[:scheme]}://#{options[:host]}", options)
    end

    def request(params, &block)
      if @api_key
        params[:query] = {
          'api_key' => @api_key,
        }.merge(params[:query] || {})
      end
      
      begin
        response = @connection.request(params, &block)
      rescue Excon::Errors::HTTPStatusError => error
        klass = case error.response.status
          when 401 then Pebbles::API::Errors::Unauthorized
          when 402 then Pebbles::API::Errors::VerificationRequired
          when 403 then Pebbles::API::Errors::Forbidden
          when 404
            if error.request[:path].match /\/apps\/\/.*/
              Pebbles::API::Errors::NilApp
            else
              Pebbles::API::Errors::NotFound
            end
          when 408 then Pebbles::API::Errors::Timeout
          when 422 then Pebbles::API::Errors::RequestFailed
          when 423 then Pebbles::API::Errors::Locked
          when 429 then Pebbles::API::Errors::RateLimitExceeded
          when /50./ then Pebbles::API::Errors::RequestFailed
          else Pebbles::API::Errors::ErrorWithResponse
        end

        decompress_response!(error.response)
        reerror = klass.new(error.message, error.response)
        reerror.set_backtrace(error.backtrace)
        raise(reerror)
      end

      if response.body && !response.body.empty?
        decompress_response!(response)
        begin
          response.body = MultiJson.load(response.body)
        rescue
          # leave non-JSON body as is
        end
      end

      # reset (non-persistent) connection
      @connection.reset
      
      if response.headers.has_key?('X-Pebbles-Warning')
        Pebbles::Command.warnings.concat(response.headers['X-Pebbles-Warning'].split("\n"))
      end
          
      response
    end

    private

    def decompress_response!(response)
      return unless response.headers['Content-Encoding'] == 'gzip'
      response.body = Zlib::GzipReader.new(StringIO.new(response.body)).read
    end
    
    def app_params(params)
      app_params = {}
      params.each do |key, value|
        app_params["app[#{key}]"] = value
      end
      app_params
    end
  end
end
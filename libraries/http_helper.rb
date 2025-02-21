require 'net/http'
require 'json'

module HTTPHelper
  class << self
    # Function to get a new access token using a refresh token
    # Helper function to create a new access token from provided access_key and secret_key
    def get_new_access_token(access_key, secret_key, chef_platform_url, api_port, ssl_mode)
      url = "#{chef_platform_url}:#{api_port}/platform/user-accounts/v1/user/api-token/login"
      payload = { 'accessKey' => access_key, 'secretKey' => secret_key, 'state' => 'random-string' }
      uri = URI.parse(url)
      header = { 'Content-Type': 'application/json' }
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      if ssl_mode == 'verify_peer'
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      end
      request = Net::HTTP::Post.new(uri.request_uri, header)
      request.body = payload.to_json
      response = http.request(request)
      response = handle_response(url, response)
      data = JSON.parse(response.body)
      oauth_code = data['item']['oauthCode']

      url = "#{chef_platform_url}:#{api_port}/platform/user-accounts/v1/user/api-token/jwt"
      payload = { 'oauthCode' => oauth_code, 'state' => 'random-string' }
      uri = URI.parse(url)
      header = { 'Content-Type': 'application/json' }
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      if ssl_mode == 'verify_peer'
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      end
      request = Net::HTTP::Post.new(uri.request_uri, header)
      request.body = payload.to_json
      response = http.request(request)
      response = handle_response(url, response)
      data = JSON.parse(response.body)
      access_token = data['item']['accessToken']
      refresh_token = data['item']['refreshToken']
      [access_token, refresh_token]
    end

    # def http_request(url, payload, http_method, access_token = nil, refresh_token = nil, chef_platform_url = nil)
    def http_request(url, payload, http_method, access_token = nil, ssl_mode)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      if ssl_mode == 'verify_peer'
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      end
      request = if http_method == 'put'
                  Net::HTTP::Put.new(uri.request_uri)
                else
                  Net::HTTP::Post.new(uri.request_uri)
                end
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{access_token}" if access_token
      request.body = payload.to_json
      response = http.request(request)
      response = handle_response(url, response)

      JSON.parse(response.body)
    end

    def handle_response(url, response)
      max_retries = 3
      attempts = 0

      begin
        case response
        when Net::HTTPSuccess
          Chef::Log.info("Success: #{response.body}")
        else
          Chef::Log.error("HTTP Error: #{response.code} #{response.message}")
          raise SocketError
        end
        response
      rescue SocketError, Timeout::Error => e
        attempts += 1
        if attempts < max_retries
          Chef::Log.warn("#{url} failed. Retrying...(attempt #{attempts})")
          retry
        else
          Chef::Log.fatal("#{url} failed. Stopping Chef client")
          raise "Failed after #{max_retries} attempts: #{e.message} for API: #{url}"
        end
      rescue StandardError => e
        Chef::Log.fatal("An error occurred for API #{url}: #{e.message}")
        raise "An error occurred for API #{url}: #{e.message}"
      end
    end
  end
end

#
# Chef Infra Documentation
# https://docs.chef.io/libraries/
#

#
# This module name was auto-generated from the cookbook name. This name is a
# single word that starts with a capital letter and then continues to use
# camel-casing throughout the remainder of the name.
#
# libraries/node_management_helpers.rb

module NodeManagementHelpers
  module Credentials
    def obtain_node_credentials(ssl_mode)
      chef_platform_url = new_resource.chef_platform_url
      cohort_id = new_resource.cohort_id
      access_key = new_resource.access_key
      secret_key = new_resource.secret_key
      api_port = new_resource.api_port

      # 1. Generate a random UUID
      node_id = SecureRandom.uuid

      access_token, _refresh_token = HTTPHelper.get_new_access_token(access_key, secret_key, chef_platform_url, api_port, ssl_mode)

      # 2. Create a node with the ID
      url = "#{chef_platform_url}:#{api_port}/node/management/v1/nodes"
      payload = {
        'id' => node_id,
        'cohortId' => cohort_id,
        'source' => 'enrollment',
        'attributes' => [
          {
            'name' => 'fqdn',
            'value' => node['ipaddress'],
            'namespace' => 'enroll',
          },
          {
            'name' => 'enrollment_source',
            'value' => 'cookbook',
            'namespace' => 'enroll',
          },
        ],
      }
      response = HTTPHelper.http_request(url, payload, 'post', access_token, ssl_mode)
      reg_node_id = response['item']['nodeId']
      Chef::Log.info("reg_node_id: #{reg_node_id}")

      # 3. Register the Node with Auth system
      url = "#{chef_platform_url}:#{api_port}/platform/node-accounts/v1/node"
      payload = { 'nodeRefId' => node_id }
      response = HTTPHelper.http_request(url, payload, 'post', access_token, ssl_mode)
      node_auth_id = response['item']['id']
      # node_ref_id = response['item']['nodeRefId']
      Chef::Log.info("node_auth_id: #{node_auth_id}")

      # Define node_role_id
      # DO NOT MODIFY: This will same for Chef-360 platform future release
      node_role_id = node['enroll']['node_role_id']

      # 4. Assign the Node the Node Management Role
      url = "#{chef_platform_url}:#{api_port}/platform/node-accounts/v1/node/#{node_auth_id}/role"
      payload = { 'name' => 'node-management-agent', 'roleId' => node_role_id }
      _response = HTTPHelper.http_request(url, payload, 'post', access_token, ssl_mode)
      # node_security_role_id = response['item']['id']

      # 5. Force new credential rotation on the Node
      url = "#{chef_platform_url}:#{api_port}/platform/node-accounts/v1/node/#{node_auth_id}/role/#{node_role_id}/credentials/rotate"
      payload = { 'nodeRefId' => reg_node_id }
      response = HTTPHelper.http_request(url, payload, 'put', access_token, ssl_mode)

      [node_id, response['item']['nodeRoleLinkId'], response['item']['privateCert'], response['item']['publicCert']]
    end
  end
end

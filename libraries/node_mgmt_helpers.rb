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
    def obtain_node_credentials
      chef_platform_url = new_resource.chef_platform_url
      cohort_id = new_resource.cohort_id
      access_key = new_resource.access_key
      secret_key = new_resource.secret_key
      api_port = new_resource.api_port

      # 1. Generate a random UUID
      node_id = SecureRandom.uuid

      access_token, _refresh_token = HTTPHelper.get_new_access_token(access_key, secret_key, chef_platform_url, api_port)

      # 2. Create a node with the ID
      url = "#{chef_platform_url}:#{api_port}/node/management/v1/nodes"
      payload = { 'id' => node_id, 'cohortId' => cohort_id, 'source' => 'enrollment' }
      response = HTTPHelper.http_request(url, payload, 'post', access_token)
      reg_node_id = response['item']['nodeId']

      # 3. Register the Node with Auth system
      url = "#{chef_platform_url}:#{api_port}/platform/node-accounts/v1/node"
      payload = { 'nodeRefId' => reg_node_id }
      response = HTTPHelper.http_request(url, payload, 'post', access_token)
      node_auth_id = response['item']['id']
      # node_ref_id = response['item']['nodeRefId']

      # Define node_role_id
      # DO NOT MODIFY: This will same for Chef-360 platform future release
      node_role_id = node['enroll']['node_role_id']

      # 4. Assign the Node the Node Management Role
      url = "#{chef_platform_url}:#{api_port}/platform/node-accounts/v1/node/#{node_auth_id}/role"
      payload = { 'name' => 'node-management-agent', 'roleId' => node_role_id }
      _response = HTTPHelper.http_request(url, payload, 'post', access_token)
      # node_security_role_id = response['item']['id']

      # 5. Force new credential rotation on the Node
      url = "#{chef_platform_url}:#{api_port}/platform/node-accounts/v1/node/#{node_auth_id}/role/#{node_role_id}/credentials/rotate"
      payload = { 'nodeRefId' => reg_node_id }
      response = HTTPHelper.http_request(url, payload, 'put', access_token)

      [node_id, response['item']['nodeRoleLinkId'], response['item']['privateCert']]
    end
  end
end

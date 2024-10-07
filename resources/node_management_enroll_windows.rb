# To learn more about Custom Resources, see https://docs.chef.io/custom_resources.html
#
# Author:: Varun Sharma
# Cookbook:: chef-cookbook-enroll
# Resource:: node_management_enroll
#
# Copyright:: 2024, Progress Software

provides :node_management_enroll, os: 'windows'
unified_mode true

use 'shared/_common'
use 'shared/_handle_full_enroll'
use 'shared/_handle_partial_enroll'

default_action :enroll

action :enroll do
  if new_resource.enroll_type == 'partial'
    Chef::Log.error('Partial enrollment on Windows is not yet supported')
    raise 'Partial enrollment on Windows is not yet supported'
  end
  register_node
  if node.default['enroll']['enrolled']
    new_resource.updated_by_last_action(false)
  else
    converge_by('Enrolling_Node') { enroll_node_full }
  end
end

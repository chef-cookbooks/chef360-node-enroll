# To learn more about Custom Resources, see https://docs.chef.io/custom_resources.html
#
# Author:: Varun Sharma
# Cookbook:: chef-cookbook-enroll
# Resource:: node_management_enroll
#
# Copyright:: 2024, Progress Software
provides :node_management_enroll, os: 'linux'
unified_mode true

use 'shared/_common'
use 'shared/_handle_full_enroll'
use 'shared/_handle_partial_enroll'

default_action :enroll

action :enroll do
  register_node

  case new_resource.enroll_type
  when 'full'
    if node.default['enroll']['enrolled']
      new_resource.updated_by_last_action(false)
    else
      converge_by('Enrolling_Node') { enroll_node_full }
    end

  when 'partial'
    if !new_resource.upgrade_skills
      if node.default['enroll']['enrolled']
        new_resource.updated_by_last_action(false)
      else
        converge_by('Enrolling_Node') { enroll_node_partial }
      end
    elsif new_resource.upgrade_skills && node.default['enroll']['enrolled']
      converge_by('Enrolling_Node') { enroll_node_partial }
    end

  else
    Chef::Log.error("Unsupported enroll_type: #{new_resource.enroll_type}")
    raise "Unsupported enroll_type: #{new_resource.enroll_type}"
  end
end

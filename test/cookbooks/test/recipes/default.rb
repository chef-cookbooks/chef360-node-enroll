#
# Cookbook:: chef360-node-enroll
# Recipe:: default
#
# Copyright:: 2024, The Authors, All Rights Reserved.

node_management_enroll 'Enroll Node' do
  chef_platform_url node['enroll']['chef_platform_url']
  enroll_type 'partial'
  api_port node['enroll']['api_port']
  access_key node['enroll']['access_key']
  secret_key node['enroll']['secret_key']
  cohort_id node['enroll']['cohort_id']
  hab_builder_url node['enroll']['hab_builder_url']
  working_dir_path node['enroll']['working_dir_path']
end

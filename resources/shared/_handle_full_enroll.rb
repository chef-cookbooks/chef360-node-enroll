chef_version = Gem::Version.new(node['chef_packages']['chef']['version'])
if chef_version < Gem::Version.new('18.5.0')
  cache_path = Chef::Config[:file_cache_path]
  if platform?('windows')
    use "#{cache_path}/cookbooks/#{node['enroll']['cookbook_name']}/resources/shared/_win_full_enroll.rb"
  else
    use "#{cache_path}/cookbooks/#{node['enroll']['cookbook_name']}/resources/shared/_linux_full_enroll.rb"
  end
elsif platform?('windows')
  use 'shared/_win_full_enroll'
else
  use 'shared/_linux_full_enroll'
end

action_class do
  def enroll_node_full
    install_hab_full
    install_node_mgmt_full
  end
end

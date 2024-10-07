chef_version = Gem::Version.new(node['chef_packages']['chef']['version'])
if chef_version < Gem::Version.new('18.5.0')
  cache_path = Chef::Config[:file_cache_path]
  use "#{cache_path}/cookbooks/#{node['enroll']['cookbook_name']}/resources/shared/_download_packages.rb"
  if platform?('windows')
    # use "#{cache_path}/cookbooks/#{node['enroll']['cookbook_name']}/resources/shared/_win_partial_enroll.rb"
  else
    use "#{cache_path}/cookbooks/#{node['enroll']['cookbook_name']}/resources/shared/_linux_partial_enroll.rb"
  end
else
  use 'shared/_download_packages'
  if platform?('windows')
    # use 'shared/_win_partial_enroll.rb'
  else
    use 'shared/_linux_partial_enroll.rb'
  end
end

action_class do
  def enroll_node_partial
    install_toml

    download_tool_packages

    # Install Node Management Agent and confgure it as a system service
    install_node_mgmt_partial

    # Wait till all the skills required file under 'node-management-agent/data/skills/' are created
    wait_till_data_skills_files_are_present

    # Install Interpreters
    interpreters = node['enroll']['interpreters']
    interpreters.each do |interpreter|
      install_tool(interpreter, false)
    end

    # Install Chef Gohai and confgure it as a system service
    install_chef_gohai

    # Install Courier Runner and confgure it as a system service
    install_chef_runner
  end
end

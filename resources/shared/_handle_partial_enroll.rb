chef_version = Gem::Version.new(node['chef_packages']['chef']['version'])
if chef_version < Gem::Version.new('18.0.0')
  resource_path = ::File.join(Chef::Config[:file_cache_path],
    'cookbooks', node['enroll']['cookbook_name'],
    'resources', 'shared', '_download_packages.rb')
  instance_eval(IO.read(resource_path), resource_path)

  if platform?('windows')
    # NOT YET SUPPORTED
  else
    resource_path = ::File.join(Chef::Config[:file_cache_path],
      'cookbooks', node['enroll']['cookbook_name'],
      'resources', 'shared', '_linux_partial_enroll.rb')
  end
  instance_eval(IO.read(resource_path), resource_path)
elsif platform?('windows')
  # NOT YET SUPPORTED
else
  use 'shared/_download_packages'
  use 'shared/_linux_partial_enroll.rb'
end

action_class do
  def enroll_node_partial
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

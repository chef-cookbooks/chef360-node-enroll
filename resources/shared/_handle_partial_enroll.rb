chef_version = Gem::Version.new(node['chef_packages']['chef']['version'])

# Instead of defining a method outside any scope, define a local variable with the path logic
base_path = ::File.join(Chef::Config[:file_cache_path], 'cookbooks', node['enroll']['cookbook_name'], 'resources', 'shared')

# First load download_packages
download_packages_path = ::File.join(base_path, '_download_packages.rb')

begin
  if chef_version < Gem::Version.new('18.3.0')
    # Add validation before loading
    unless ::File.exist?(download_packages_path)
      Chef::Log.error("Download packages file not found at: #{download_packages_path}")
      raise "Required resource file missing: #{download_packages_path}"
    end

    # Log which file is being loaded
    Chef::Log.info("Loading download packages file via instance_eval: #{download_packages_path}")
    instance_eval(IO.read(download_packages_path), download_packages_path)
  else
    Chef::Log.info("Loading download packages resource via 'use' directive")
    use 'shared/_download_packages'
  end

  # Then load platform specific partial enrollment
  if platform?('windows')
    # Windows partial enrollment is not yet supported
    Chef::Log.warn('Partial enrollment on Windows is not supported')
  else
    partial_enroll_path = ::File.join(base_path, '_linux_partial_enroll.rb')

    if chef_version < Gem::Version.new('18.3.0')
      # Add validation before loading
      unless ::File.exist?(partial_enroll_path)
        Chef::Log.error("Partial enrollment file not found at: #{partial_enroll_path}")
        raise "Required resource file missing: #{partial_enroll_path}"
      end

      # Log which file is being loaded
      Chef::Log.info("Loading partial enrollment file via instance_eval: #{partial_enroll_path}")
      instance_eval(IO.read(partial_enroll_path), partial_enroll_path)
    else
      Chef::Log.info("Loading Linux partial enrollment resource via 'use' directive")
      use 'shared/_linux_partial_enroll'
    end
  end
rescue StandardError => e
  Chef::Log.error("Failed to load partial enrollment resource: #{e.message}")
  raise "Chef360 partial enrollment failed during resource loading: #{e.message}"
end

# The action_class block defines helper methods that can be used within the resource's actions.
# Here, it includes the `enroll_node_partial` method, which orchestrates the partial enrollment process
action_class do
  def enroll_node_partial
    Chef::Log.info('Beginning partial node enrollment process')
    download_tool_packages

    # Install Node Management Agent and configure it as a system service
    install_node_mgmt_partial

    # Wait till all the skills required file under 'node-management-agent/data/skills/' are created
    wait_till_data_skills_files_are_present

    # Install Interpreters
    interpreters = node['enroll']['interpreters']
    interpreters.each do |interpreter|
      install_tool(interpreter, false)
    end

    # Install Chef Gohai and configure it as a system service
    install_chef_gohai

    # Install Courier Runner and configure it as a system service
    install_chef_runner
    Chef::Log.info('Partial node enrollment completed successfully')
  rescue StandardError => e
    Chef::Log.error("Failed to enroll node partially: #{e.message}")
    raise
  end
end

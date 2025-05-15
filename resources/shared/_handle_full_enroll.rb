chef_version = Gem::Version.new(node['chef_packages']['chef']['version'])

# Instead of defining a method outside any scope, define a local variable with the path logic
base_path = ::File.join(Chef::Config[:file_cache_path], 'cookbooks', node['enroll']['cookbook_name'], 'resources', 'shared')
resource_path = if platform?('windows')
                  ::File.join(base_path, '_win_full_enroll.rb')
                else
                  ::File.join(base_path, '_linux_full_enroll.rb')
                end

begin
  if chef_version < Gem::Version.new('18.3.0')
    # Add validation before loading
    unless ::File.exist?(resource_path)
      Chef::Log.error("Resource file not found at: #{resource_path}")
      raise "Required resource file missing: #{resource_path}"
    end

    # Log which file is being loaded
    Chef::Log.info("Loading resource file via instance_eval: #{resource_path}")
    instance_eval(IO.read(resource_path), resource_path)
  elsif platform?('windows')
    Chef::Log.info("Loading Windows enrollment resource via 'use' directive")
    use 'shared/_win_full_enroll'
  else
    Chef::Log.info("Loading Linux enrollment resource via 'use' directive")
    use 'shared/_linux_full_enroll'
  end
rescue StandardError => e
  Chef::Log.error("Failed to load enrollment resource: #{e.message}")
  raise "Chef360 enrollment failed during resource loading: #{e.message}"
end

# The action_class block defines helper methods that can be used within the resource's actions.
# Here, it includes the `enroll_node_full` method, which orchestrates the full enrollment process
# by calling `install_hab_full` and `install_node_mgmt_full`.
action_class do
  def enroll_node_full
    Chef::Log.info('Beginning full node enrollment process')
    install_hab_full
    install_node_mgmt_full
    Chef::Log.info('Full node enrollment completed successfully')
  rescue StandardError => e
    Chef::Log.error("Failed to enroll node fully: #{e.message}")
    raise
  end
end

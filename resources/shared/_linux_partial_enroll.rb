action_class do
  def install_node_mgmt_partial
    manage_nodeman_config_file

    config_file_path = "#{new_resource.chef_tools_dir_path}/#{node['enroll']['nodeman_pkg']}/config/config.yaml"
    service_vars = {}
    if platform?('mac_os_x')
      binary_path = "#{new_resource.chef_tools_dir_path}/#{node['enroll']['nodeman_pkg']}/#{node['enroll']['nodeman_pkg']}"
      binary_arguments = [
        'run',
        "#{new_resource.chef_tools_dir_path}/#{node['enroll']['nodeman_pkg']}/config/config.yaml",
      ]
      service_vars[:binary_path] = binary_path
      service_vars[:binary_arguments] = binary_arguments
    else
      service_vars[:exec_start] = "#{new_resource.chef_tools_dir_path}/#{node['enroll']['nodeman_pkg']}/#{node['enroll']['nodeman_pkg']} run #{config_file_path}"
    end
    install_tool("#{node['enroll']['nodeman_pkg']}", true, node['enroll']['nodeman_pkg'], service_vars)
  end

  def wait_till_data_skills_files_are_present
    runner_data_file_path = "#{new_resource.chef_tools_dir_path}/#{node['enroll']['nodeman_pkg']}/data/skills/#{node['enroll']['runner_pkg']}/config/courier-runner-template"
    gohai_data_file_path = "#{new_resource.chef_tools_dir_path}/#{node['enroll']['nodeman_pkg']}/data/skills/#{node['enroll']['gohai_pkg']}/config/chef-gohai-template"

    data_file_paths = [runner_data_file_path, gohai_data_file_path]

    data_file_paths.each do |data_file_path|
      bash 'wait_for_runner_template_file' do
        code <<-EOH
          file_path="#{data_file_path}"
          timeout=120
          elapsed=0
          interval=1

          while [ ! -f "$file_path" ]; do
            sleep $interval
            elapsed=$((elapsed + interval))
            if [ $elapsed -ge $timeout ]; then
              echo "Timeout reached: $file_path not found within $timeout seconds."
              exit 1
            fi
          done

          echo "$file_path is present."
          exit 0
        EOH
        action :run
      end
    end
  end

  def install_tool(tool_name, is_service, service_name = nil, service_template_vars = nil)
    extract_tool_package(tool_name)

    if is_service
      create_service(service_name, service_template_vars)
    end
  end

  def install_chef_gohai
    is_secure = new_resource.chef_platform_url.start_with?('https')
    courier_gohai_default_file = "#{new_resource.chef_tools_dir_path}/#{node['enroll']['nodeman_pkg']}/data/skills/#{node['enroll']['gohai_pkg']}/config/chef-gohai-template"
    platform_credential_path = "#{new_resource.chef_tools_dir_path}/#{node['enroll']['nodeman_pkg']}/data/chef-gohai-key.pem"
    config_file_path = "#{new_resource.chef_tools_dir_path}/#{node['enroll']['gohai_pkg']}/config/config.toml"
    exec_start_cmd = "#{new_resource.chef_tools_dir_path}/#{node['enroll']['gohai_pkg']}/#{node['enroll']['gohai_pkg']} run #{config_file_path}"
    log_dir = "#{new_resource.chef_tools_dir_path}/#{node['enroll']['gohai_pkg']}/logs"
    ca_cert_path  = ""
    if is_secure
      ca_cert_path = "#{new_resource.chef_tools_dir_path}/#{node['enroll']['nodeman_pkg']}/data/ca-cert.pem"
    end

    content = TOML.load_file(courier_gohai_default_file)

    service_template_vars = {}
    service_template_vars[:log_dir] = log_dir
    service_template_vars[:node_id] = node['enroll']['node_id']
    service_template_vars[:chef_platform_url] = new_resource.chef_platform_url
    service_template_vars[:api_port] = new_resource.api_port
    service_template_vars[:node_role_link_id] = content['gohai']['node_role_link_id']
    service_template_vars[:platform_credential_path] = platform_credential_path
    service_template_vars[:ca_cert_path] = ca_cert_path
    service_template_vars[:insecure] = !is_secure
    create_tool_config_file(node['enroll']['gohai_pkg'], 'gohai_config.erb', service_template_vars, 'config.toml')

    service_vars = {}
    if platform?('mac_os_x')
      binary_path = "#{new_resource.chef_tools_dir_path}/#{node['enroll']['gohai_pkg']}/#{node['enroll']['gohai_pkg']}"
      binary_arguments = [
        'run',
        "#{config_file_path}",
      ]
      service_vars[:binary_path] = binary_path
      service_vars[:binary_arguments] = binary_arguments
    else
      service_vars[:exec_start] = exec_start_cmd
    end
    install_tool(node['enroll']['gohai_pkg'], true, node['enroll']['gohai_pkg'], service_vars)
  end

  # Handles both Linux, Mac
  def install_chef_runner
    is_secure = new_resource.chef_platform_url.start_with?('https')
    courier_runner_template_file = "#{new_resource.chef_tools_dir_path}/#{node['enroll']['nodeman_pkg']}/data/skills/#{node['enroll']['runner_pkg']}/config/courier-runner-template"
    platform_credential_path = "#{new_resource.chef_tools_dir_path}/#{node['enroll']['nodeman_pkg']}/data/courier-runner-key.pem"
    log_dir = "#{new_resource.chef_tools_dir_path}/#{node['enroll']['runner_pkg']}/logs"
    data_dir = "#{new_resource.chef_tools_dir_path}/#{node['enroll']['runner_pkg']}/data"
    config_file_path = "#{new_resource.chef_tools_dir_path}/#{node['enroll']['runner_pkg']}/config/config.yaml"
    exec_start_cmd = "#{new_resource.chef_tools_dir_path}/#{node['enroll']['runner_pkg']}/#{node['enroll']['runner_pkg']} --config #{config_file_path}"
    ca_cert_path  = ""
    if is_secure
      ca_cert_path = "#{new_resource.chef_tools_dir_path}/#{node['enroll']['nodeman_pkg']}/data/ca-cert.pem"
    end

    content = TOML.load_file(courier_runner_template_file)

    service_template_vars = {}
    service_template_vars[:log_dir] = log_dir
    service_template_vars[:node_id] = node['enroll']['node_id']
    service_template_vars[:chef_platform_url] = new_resource.chef_platform_url
    service_template_vars[:data_dir] = data_dir
    service_template_vars[:api_port] = new_resource.api_port
    service_template_vars[:node_role_link_id] = content['gateway_config']['node_role_link_id']
    service_template_vars[:platform_credential_path] = platform_credential_path
    service_template_vars[:chef_tools_dir_path] = new_resource.chef_tools_dir_path
    service_template_vars[:ca_cert_path] = ca_cert_path
    service_template_vars[:insecure] = !is_secure
    create_tool_config_file(node['enroll']['runner_pkg'], 'courier_runner_config.erb', service_template_vars, 'config.yaml')

    service_vars = {}
    if platform?('mac_os_x')
      binary_path = "#{new_resource.chef_tools_dir_path}/#{node['enroll']['runner_pkg']}/#{node['enroll']['runner_pkg']}"
      binary_arguments = [
        '--config',
        "#{new_resource.chef_tools_dir_path}/#{node['enroll']['runner_pkg']}/config/config.yaml",
      ]
      service_vars[:binary_path] = binary_path
      service_vars[:binary_arguments] = binary_arguments
    else
      service_vars[:exec_start] = exec_start_cmd
    end

    install_tool(node['enroll']['runner_pkg'], true, node['enroll']['runner_pkg'], service_vars)
  end

  def extract_tool_package(tool_name)
    dir = "#{new_resource.chef_tools_dir_path}/#{tool_name}/"
    files = ::Dir.glob(::File.join(dir, '*.tar.gz'))
    if files.nil? || files.empty?
      return
    end

    file_name = ::File.basename(files.first)

    # Special handling to revert back the node-management base dir name to node['enroll']['nodeman_pkg']
    # This is required to have the binary and dir name in-sync with FULL enrollment
    new_tool_name = if tool_name == 'chef-node-management-agent'
                      node['enroll']['nodeman_pkg']
                    else
                      tool_name
                    end
    bash 'extract_package' do
      code <<-EOH
      tar -xvzf "#{new_resource.chef_tools_dir_path}/#{tool_name}/#{file_name}" -C "#{new_resource.chef_tools_dir_path}/#{new_tool_name}"
      if [ -f "#{new_resource.chef_tools_dir_path}/#{new_tool_name}/chef-node-management-agent" ]; then
        mv "#{new_resource.chef_tools_dir_path}/#{new_tool_name}/chef-node-management-agent" "#{new_resource.chef_tools_dir_path}/#{new_tool_name}/#{node['enroll']['nodeman_pkg']}"
      fi
      if [ -d "#{new_resource.chef_tools_dir_path}/chef-node-management-agent" ]; then
        rm -rf "#{new_resource.chef_tools_dir_path}/chef-node-management-agent"
      fi

      # Set permissions if OS is macOS
      if [ "$(uname)" == "Darwin" ]; then
        chown root:wheel "#{new_resource.chef_tools_dir_path}/#{new_tool_name}/#{new_tool_name}"
        chmod 755 "#{new_resource.chef_tools_dir_path}/#{new_tool_name}/#{new_tool_name}"
      fi
      EOH
      action :run
      only_if { ::File.exist?("#{new_resource.chef_tools_dir_path}/#{new_tool_name}/#{file_name}") }
    end

    file "#{new_resource.chef_tools_dir_path}/#{new_tool_name}/#{file_name}" do
      action :delete
    end
  end

  # Handles Linux and MacOS
  def create_service(service_name, service_unit_template_vars)
    if platform?('mac_os_x')
      create_service_mac(service_name, service_unit_template_vars)
    else
      create_service_linux(service_name, service_unit_template_vars)
    end
  end

  # Creates a systemd service unit file for a specified service and starts the service on a Linux system.
  #
  # @param service_name [String] the name of the service to be created and started
  # @param service_unit_template_vars [Hash] a hash of variables to be passed to the service unit template
  #
  # This method performs the following steps:
  # 1. Creates a systemd service unit file at /etc/systemd/system/#{service_name}.service using the specified template and variables.
  # 2. Enables and starts the service using the `service` resource.
  #
  # Note: The method expects the service unit template to be located at 'tool.service.erb'.
  def create_service_linux(service_name, service_unit_template_vars)
    service_unit_template_vars[:tool_name] = service_name
    template "/etc/systemd/system/#{service_name}.service" do
      cookbook node['enroll']['cookbook_name']
      source 'tool.service.erb'
      variables(
        service_unit_template_vars
      )
      action :create
    end

    service service_name do
      action [:enable, :start]
    end
  end

  def create_service_mac(service_name, service_unit_template_vars)
    service_unit_template_vars[:tool_name] = service_name

    current_user_launchagent_dir = '/var/root/Library/LaunchAgent'

    directory current_user_launchagent_dir do
      recursive true
    end

    plist_path = "#{current_user_launchagent_dir}/#{service_name}.plist"

    current_user = ENV['USER']
    home_env = '/var/root'

    unless current_user == 'root'
      home_env = "/Users/#{current_user}"
    end

    service_unit_template_vars[:home_env] = home_env

    template plist_path do
      cookbook node['enroll']['cookbook_name']
      source 'tool.plist.erb'
      variables(
        service_unit_template_vars
      )
      owner 'root'
      group 'wheel'
      mode '0644'
      action :create
    end

    execute "load_#{service_name}" do
      command "launchctl bootstrap system #{plist_path}"
      not_if { `launchctl list | grep #{service_name}`.include?(service_name) }
    end
  end
end

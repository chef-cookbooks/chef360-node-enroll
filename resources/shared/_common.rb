property :chef_platform_url, String, required: true
property :enroll_type, String, default: 'full'
property :api_port, String, default: '31000'
property :access_key, String, required: true, sensitive: true
property :secret_key, String, required: true, sensitive: true
property :cohort_id, String, required: true
property :hab_builder_url, String, default: 'https://bldr.habitat.sh'
property :working_dir_path, String, default: '/tmp'
property :chef_tools_dir_path, String, default: '/etc/chef_platform/tools'
property :upgrade_skills, [true, false], default: false
property :root_ca, String, sensitive: true
property :ssl_verify_mode, Symbol, equal_to: [:verify_peer, :verify_none], default: :verify_none

action_class do
  include NodeManagementHelpers::Credentials

  def register_node
    # Check if node is already enrolled
    node_guid_file = node['enroll']['node_guid_file']

    if new_resource.enroll_type == 'partial'
      node_guid_file = if platform?('windows')
                         "#{new_resource.chef_tools_dir_path}\\#{node['enroll']['nodeman_pkg']}\\data\\node_guid"
                       else
                         "#{new_resource.chef_tools_dir_path}/#{node['enroll']['nodeman_pkg']}/data/node_guid"
                       end
    end

    node.default['enroll']['enrolled'] = ::File.exist?(node_guid_file)

    if node['enroll']['enrolled']
      node_uuid = shell_out("#{platform?('windows') ? 'type' : 'cat'} #{node_guid_file}").stdout.chomp
      node.default['enroll']['node_id'] = node_uuid
    else
      Chef::Log.info('Node is not enrolled, enrolling...')
      if isNodeRegistered
        Chef::Log.info('Node is already registered')
        node_id, node_role_link_id, node_private_cert, node_public_cert = get_node_credentials
        Chef::Log.info('Node ID: ' + node_id)
        Chef::Log.info('Node Role Link ID: ' + node_role_link_id)
        Chef::Log.info('Node Private Cert: ' + node_private_cert)
        Chef::Log.info('Node Public Cert: ' + node_public_cert)

        # Store the local credentials in node attributes
        node.default['enroll']['node_id'] = node_id
        node.default['enroll']['node_role_link_id'] = node_role_link_id
        node.default['enroll']['node_private_cert'] = node_private_cert
        node.default['enroll']['node_public_cert'] = node_public_cert
      else
        Chef::Log.info('Node is not registered.Obtaining node credentials...')

        node_id, node_role_link_id, node_private_cert, node_public_cert = obtain_node_credentials(new_resource.ssl_verify_mode)
        Chef::Log.info('Node ID: ' + node_id)
        Chef::Log.info('Node Role Link ID: ' + node_role_link_id)
        Chef::Log.info('Node Private Cert: ' + node_private_cert)
        Chef::Log.info('Node Public Cert: ' + node_public_cert)

        # Store the local credentials in node attributes
        node.default['enroll']['node_id'] = node_id
        node.default['enroll']['node_role_link_id'] = node_role_link_id
        node.default['enroll']['node_private_cert'] = node_private_cert
        node.default['enroll']['node_public_cert'] = node_public_cert
        create_node_credential_files(node_id, node_role_link_id, node_private_cert, node_public_cert)
      end
    end
  end

  # Handles both Linux and Windows
  def create_tool_config_file(tool_name, service_template_source, service_template_vars, config_file_name)
    config_dir_loc = "#{new_resource.chef_tools_dir_path}/#{tool_name}/config"
    log_dir_loc = "#{new_resource.chef_tools_dir_path}/#{tool_name}/logs"
    if platform?('windows')
    end
    data_dir_loc = "#{new_resource.chef_tools_dir_path}/#{tool_name}/data"
    config_file = "#{config_dir_loc}/#{config_file_name}"

    config_dirs = [data_dir_loc, config_dir_loc, log_dir_loc]
    config_dirs.each do |dir|
      directory dir do
        recursive true
      end
    end

    template "#{config_file}" do
      cookbook node['enroll']['cookbook_name']
      source service_template_source
      variables(
        service_template_vars
      )
      action :create
    end
  end

  def manage_nodeman_config_file
    unless node['enroll']['enrolled']
      define_node_mgmt_config_dirs
      create_node_mgmt_config_files
    end
  end

  def create_node_mgmt_config_files
    define_node_mgmt_config_dirs

    local_config_dir_loc = @config_dir_loc
    local_data_dir_loc = @data_dir_loc
    local_log_dir_loc = @log_dir_loc
    local_user_toml = @user_toml
    local_agent_key_path = @agent_key
    local_ca_cert_path = @ca_cert
    local_node_guid = @node_guid
    local_nodman_config = @nodman_config

    is_secure = new_resource.chef_platform_url.start_with?('https')

    config_template_source = new_resource.enroll_type == 'partial' ? 'nodman_config.yaml_partial.erb' : 'nodman_config.yaml_full.erb'

    config_dirs = [local_data_dir_loc, local_config_dir_loc, local_log_dir_loc]
    config_dirs.each do |dir|
      directory dir do
        recursive true
      end
    end

    if is_secure
      file "#{local_ca_cert_path}" do
        content new_resource.root_ca
        action :create
      end
    else
      local_ca_cert_path = ''
    end

    file "#{local_agent_key_path}" do
      content node['enroll']['node_private_cert']
      action :create
    end

    file "#{local_node_guid}" do
      content node['enroll']['node_id']
      action :create
    end

    template "#{local_user_toml}" do
      cookbook node['enroll']['cookbook_name']
      source 'user.toml.erb'
      variables(
        platform_url: new_resource.chef_platform_url,
        node_id: node['enroll']['node_id'],
        log_dir: local_log_dir_loc,
        data_dir: local_data_dir_loc,
        node_role_link_id: node['enroll']['node_role_link_id'],
        api_port: new_resource.api_port,
        platform_credentials_path: local_agent_key_path,
        insecure: !is_secure,
        ca_cert_path: local_ca_cert_path,
        hab_builder_url: new_resource.hab_builder_url
      )
      action :create
    end

    if new_resource.enroll_type == 'partial'
      if platform?('mac_os_x')
        template "#{local_nodman_config}" do
          cookbook node['enroll']['cookbook_name']
          source config_template_source
          variables(
            platform_url: new_resource.chef_platform_url,
            node_id: node['enroll']['node_id'],
            node_role_link_id: node['enroll']['node_role_link_id'],
            hab_builder_url: new_resource.hab_builder_url,
            api_port: new_resource.api_port,
            data_dir: local_data_dir_loc,
            log_dir: local_log_dir_loc,
            platform_credentials_path: "#{local_agent_key_path}",
            insecure: !is_secure,
            ca_cert_path: local_ca_cert_path
          )
          owner 'root'
          group 'wheel'
          mode '0644'
          action :create
        end
      else
        template "#{local_nodman_config}" do
          cookbook node['enroll']['cookbook_name']
          source config_template_source
          variables(
            platform_url: new_resource.chef_platform_url,
            node_id: node['enroll']['node_id'],
            node_role_link_id: node['enroll']['node_role_link_id'],
            hab_builder_url: new_resource.hab_builder_url,
            api_port: new_resource.api_port,
            data_dir: local_data_dir_loc,
            log_dir: local_log_dir_loc,
            platform_credentials_path: "#{local_agent_key_path}",
            insecure: !is_secure,
            ca_cert_path: local_ca_cert_path
          )
          action :create
        end
      end
    end
  end

  def define_node_mgmt_config_dirs
    _base_path = platform?('windows') ? 'c:/hab' : '/hab'
    user_config_path = platform?('windows') ? 'c:/hab/user' : '/hab/user'
    svc_path = platform?('windows') ? 'c:/hab/svc' : '/hab/svc'

    base_dir = if new_resource.enroll_type == 'partial'
                 "#{new_resource.chef_tools_dir_path}/#{node['enroll']['nodeman_pkg']}"
               else
                 "#{svc_path}/#{node['enroll']['nodeman_pkg']}"
               end

    @config_dir_loc = if new_resource.enroll_type == 'partial'
                        "#{base_dir}/config"
                      else
                        "#{user_config_path}/#{node['enroll']['nodeman_pkg']}/config"
                      end

    @data_dir_loc = "#{base_dir}/data"
    @log_dir_loc = "#{base_dir}/logs"
    @user_toml = "#{@config_dir_loc}/user.toml"
    @agent_key = "#{@data_dir_loc}/node-management-agent-key.pem"
    @ca_cert = "#{@data_dir_loc}/ca-cert.pem"
    @node_guid = "#{@data_dir_loc}/node_guid"
    @nodman_config = "#{@config_dir_loc}/config.yaml"
  end

  def install_toml
    chef_gem 'toml' do
      compile_time false
      action :install
    end
    require 'toml'
  end

  def create_hab_cert
    is_secure = new_resource.chef_platform_url.start_with?('https')

    unless is_secure
      return
    end

    hab_ssl_dir_path = '/hab/cache/ssl'
    if platform?('windows')
      hab_ssl_dir_path = 'C:\\hab\\cache\\ssl'
    end

    directory hab_ssl_dir_path do
      recursive true
    end

    hab_root_ca_file_name = 'root_ca.pem'
    if platform?('windows')
      file "#{hab_ssl_dir_path}\\#{hab_root_ca_file_name}" do
        content new_resource.root_ca
        action :create
      end
    else
      file "#{hab_ssl_dir_path}/#{hab_root_ca_file_name}" do
        content new_resource.root_ca
        action :create
      end
    end
  end

  # Create credential files in Chef cache location after obtaining credentials
  def create_node_credential_files(node_id, node_role_link_id, node_private_cert, node_public_cert)
    # Get the Chef cache location
    cache_dir = Chef::Config[:file_cache_path]
    credentials_dir = ::File.join(cache_dir, 'chef360_node_credentials')

    # Create the directory if it doesn't exist
    directory credentials_dir do
      recursive true
      # Use generic permissions that work on both platforms
      mode platform?('windows') ? nil : '0755'
      action :create
    end

    # Define all credentials
    credentials = [
      {
        name: 'node_id.txt',
        content: node_id,
        mode: platform?('windows') ? nil : '0644',
        sensitive: true,
      },
      {
        name: 'node_role_link_id.txt',
        content: node_role_link_id,
        mode: platform?('windows') ? nil : '0644',
        sensitive: true,
      },
      {
        name: 'node_private_cert.pem',
        content: node_private_cert,
        mode: platform?('windows') ? nil : '0600',
        sensitive: true,
      },
      {
        name: 'node_public_cert.pem',
        content: node_public_cert,
        mode: platform?('windows') ? nil : '0644',
        sensitive: false,
      },
    ]

    # Create all credential files
    credentials.each do |cred|
      file_path = ::File.join(credentials_dir, cred[:name])

      file file_path do
        # Handle line endings appropriately for the platform
        content platform?('windows') ? cred[:content].gsub(/\r?\n/, "\r\n") : cred[:content]
        # Only set mode for non-Windows platforms
        mode cred[:mode]
        sensitive cred[:sensitive]
        action :create
      end
    end

    # Log the location where files were created
    Chef::Log.info("Node credential files created in: #{credentials_dir}")
  end

  # Check if the node is already registered based on presence of credential files
  def isNodeRegistered
    # Get the Chef cache location
    cache_dir = Chef::Config[:file_cache_path]
    credentials_dir = ::File.join(cache_dir, 'chef360_node_credentials')

    # First check if credentials directory exists
    unless ::File.directory?(credentials_dir)
      Chef::Log.info("Credentials directory not found at: #{credentials_dir}")
      return false
    end

    # List of required credential files
    required_files = [
      ::File.join(credentials_dir, 'node_id.txt'),
      ::File.join(credentials_dir, 'node_role_link_id.txt'),
      ::File.join(credentials_dir, 'node_private_cert.pem'),
      ::File.join(credentials_dir, 'node_public_cert.pem'),
    ]

    # Check if all required files exist
    all_files_exist = required_files.all? { |file| ::File.exist?(file) }

    if all_files_exist
      Chef::Log.info("Node registration credential files found in: #{credentials_dir}")
    else
      missing_files = required_files.reject { |file| ::File.exist?(file) }
      Chef::Log.info("Node registration incomplete. Missing files: #{missing_files.join(', ')}")
    end

    all_files_exist
  end

  # Retrieve node credentials from the stored credential files
  def get_node_credentials
    # Get the Chef cache location
    cache_dir = Chef::Config[:file_cache_path]
    credentials_dir = ::File.join(cache_dir, 'chef360_node_credentials')

    # Define credential files to read
    credential_files = {
      node_id: ::File.join(credentials_dir, 'node_id.txt'),
      node_role_link_id: ::File.join(credentials_dir, 'node_role_link_id.txt'),
      node_private_cert: ::File.join(credentials_dir, 'node_private_cert.pem'),
      node_public_cert: ::File.join(credentials_dir, 'node_public_cert.pem'),
    }

    # Check if credentials directory exists
    unless ::File.directory?(credentials_dir)
      Chef::Log.warn("Credentials directory not found at: #{credentials_dir}")
      return nil, nil, nil, nil
    end

    # Read each credential file if it exists
    credentials = {}
    missing_files = []

    credential_files.each do |cred_type, file_path|
      if ::File.exist?(file_path)
        # Handle Windows line endings if present
        content = ::File.read(file_path)
        credentials[cred_type] = content.strip
      else
        missing_files << file_path
        credentials[cred_type] = nil
      end
    end

    # Log warning if any files are missing
    unless missing_files.empty?
      Chef::Log.warn("Some credential files are missing: #{missing_files.join(', ')}")
    end

    # Return the credentials in the same order as they're stored
    [credentials[:node_id],
           credentials[:node_role_link_id],
           credentials[:node_private_cert],
           credentials[:node_public_cert]]
  end
end

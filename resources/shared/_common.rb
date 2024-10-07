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
      node_uuid = shell_out("cat #{node_guid_file}").stdout.chomp
      node.default['enroll']['node_id'] = node_uuid
    else
      Chef::Log.info('Node is not enrolled, enrolling...')
      node_id, node_role_link_id, node_private_cert = obtain_node_credentials
      node.default['enroll']['node_id'] = node_id
      node.default['enroll']['node_role_link_id'] = node_role_link_id
      node.default['enroll']['node_private_cert'] = node_private_cert
    end
  end

  # Handles both Linux and Windows
  def create_tool_config_file(tool_name, service_template_source, service_template_vars, config_file_name)
    config_dir_loc = ''
    log_dir_loc = ''
    config_file = ''
    data_dir_loc = ''
    if platform?('windows')
      config_dir_loc = "#{new_resource.chef_tools_dir_path}\\#{tool_name}\\config"
      log_dir_loc = "#{new_resource.chef_tools_dir_path}\\#{tool_name}\\logs"
      data_dir_loc = "#{new_resource.chef_tools_dir_path}\\#{tool_name}\\data"
      config_file = "#{config_dir_loc}\\#{config_file_name}"
    else
      config_dir_loc = "#{new_resource.chef_tools_dir_path}/#{tool_name}/config"
      log_dir_loc = "#{new_resource.chef_tools_dir_path}/#{tool_name}/logs"
      data_dir_loc = "#{new_resource.chef_tools_dir_path}/#{tool_name}/data"
      config_file = "#{config_dir_loc}/#{config_file_name}"
    end

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
    local_node_guid = @node_guid
    local_nodman_config = @nodman_config

    config_template_source = new_resource.enroll_type == 'partial' ? 'nodman_config.yaml_partial.erb' : 'nodman_config.yaml_full.erb'

    config_dirs = [local_data_dir_loc, local_config_dir_loc, local_log_dir_loc]
    config_dirs.each do |dir|
      directory dir do
        recursive true
      end
    end

    template "#{local_user_toml}" do
      cookbook node['enroll']['cookbook_name']
      source 'user.toml.erb'
      variables(
        platform_url: new_resource.chef_platform_url,
        node_id: node['enroll']['node_id'],
        node_role_link_id: node['enroll']['node_role_link_id'],
        api_port: new_resource.api_port
      )
      action :create
    end

    file "#{local_agent_key_path}" do
      content node['enroll']['node_private_cert']
      action :create
    end

    file "#{local_node_guid}" do
      content node['enroll']['node_id']
      action :create
    end

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
          platform_credentials_path: "#{local_agent_key_path}"
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
          platform_credentials_path: "#{local_agent_key_path}"
        )
        action :create
      end
    end
  end

  def define_node_mgmt_config_dirs
    if platform?('windows')
      base_dir = if new_resource.enroll_type == 'partial'
                   "#{new_resource.chef_tools_dir_path}\\#{node['enroll']['nodeman_pkg']}"
                 else
                   "c:\\hab\\svc\\#{node['enroll']['nodeman_pkg']}"
                 end
      @config_dir_loc = if new_resource.enroll_type == 'partial'
                          "#{new_resource.chef_tools_dir_path}\\#{node['enroll']['nodeman_pkg']}/config"
                        else
                          "c:\\hab\\user\\#{node['enroll']['nodeman_pkg']}\\config"
                        end

      @data_dir_loc = "#{base_dir}\\data"
      @log_dir_loc = "#{base_dir}\\logs"
      @user_toml = "#{@config_dir_loc}\\user.toml"
      @agent_key = "#{@data_dir_loc}\\node-management-agent-key.pem"
      @node_guid = "#{@data_dir_loc}\\node_guid"
      @nodman_config = "#{@config_dir_loc}\\config.yaml"
    else
      base_dir = if new_resource.enroll_type == 'partial'
                   "#{new_resource.chef_tools_dir_path}/#{node['enroll']['nodeman_pkg']}"
                 else
                   "/hab/svc/#{node['enroll']['nodeman_pkg']}"
                 end
      @config_dir_loc = if new_resource.enroll_type == 'partial'
                          "#{new_resource.chef_tools_dir_path}/#{node['enroll']['nodeman_pkg']}/config"
                        else
                          "/hab/user/#{node['enroll']['nodeman_pkg']}/config"
                        end

      @data_dir_loc = "#{base_dir}/data"
      @log_dir_loc = "#{base_dir}/logs"
      @user_toml = "#{@config_dir_loc}/user.toml"
      @agent_key = "#{@data_dir_loc}/node-management-agent-key.pem"
      @node_guid = "#{@data_dir_loc}/node_guid"
      @nodman_config = "#{@config_dir_loc}/config.yaml"
    end
  end

  def install_toml
    chef_gem 'toml' do
      compile_time false
      action :install
    end
    require 'toml'
  end
end

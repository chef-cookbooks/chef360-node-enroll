action_class do
  def download_tool_packages
    directory "#{new_resource.working_dir_path}" do
      recursive true
    end

    tools = node['enroll']['tools']

    tools.each do |tool|
      new_tool_name = get_new_tool_name(tool)

      new_tool_name = new_tool_name == "chef-#{node['enroll']['nodeman_pkg']}" ? node['enroll']['nodeman_pkg'] : new_tool_name

      tool_dir_path = "#{new_resource.chef_tools_dir_path}/#{new_tool_name}"
      if platform?('windows')
        tool_dir_path = "#{new_resource.chef_tools_dir_path}\\#{new_tool_name}"
      end
      directory tool_dir_path do
        recursive true
      end

      tool_latest_version = get_tool_latest_version(tool)
      if is_tool_installed(tool)
        Chef::Log.info("#{tool} is already installed checking if higher version is available")
        handle_installed_tool(tool, tool_latest_version)
      else
        # First time install. Download the package
        download_tool_pkg(tool, tool_latest_version)
      end

      file "#{tool_dir_path}/current_version" do
        content tool_latest_version
        action :create
      end
    end
  end

  def handle_installed_tool(tool, tool_latest_version)
    tool_current_version = get_tool_current_version(tool)
    tool_latest_version_number = tool_latest_version.sub(/^v/, '')
    tool_current_version_number = tool_current_version.sub(/^v/, '')
    is_latest_greater = tool_current_version_number.nil? || tool_current_version_number.empty? || Gem::Version.new(tool_latest_version_number) > Gem::Version.new(tool_current_version_number)
    if is_latest_greater && new_resource.upgrade_skills
      # download the latest
      Chef::Log.info("tool: #{tool} higher version (#{tool_latest_version}) is available...downloading")
      download_tool_pkg(tool, tool_latest_version)
    end
  end

  def download_tool_pkg(tool, tool_latest_version)
    tool_file_name = get_tool_pkg_name(tool, tool_latest_version)
    tool_dir_name = get_new_tool_name(tool) == "chef-#{node['enroll']['nodeman_pkg']}" ? node['enroll']['nodeman_pkg'] : get_new_tool_name(tool)
    tool_pkg_file_path = "#{new_resource.chef_tools_dir_path}/#{tool_dir_name}/#{tool_file_name}"
    if platform?('windows')
      tool_pkg_file_path = "#{new_resource.chef_tools_dir_path}\\#{tool_dir_name}\\#{tool_file_name}"
    end

    remote_file tool_pkg_file_path do
      source "#{new_resource.chef_platform_url}:#{new_resource.api_port}/platform/bundledtools/v1/static/downloads/#{tool}/#{tool_file_name}"
      ssl_verify_mode new_resource.ssl_verify_mode
      action :create
    end
  end

  def get_tool_latest_version(tool)
    latest_version_file_path = "#{new_resource.working_dir_path}/latest"
    if platform?('windows')
      latest_version_file_path = "#{new_resource.working_dir_path}\\latest"
    end
    remote_file latest_version_file_path do
      source "#{new_resource.chef_platform_url}:#{new_resource.api_port}/platform/bundledtools/v1/static/downloads/#{tool}/latest"
      ssl_verify_mode new_resource.ssl_verify_mode
      action :create
    end

    latest_version = shell_out("cat #{latest_version_file_path}").stdout.chomp

    file latest_version_file_path do
      action :delete
    end
    latest_version
  end

  def get_tool_current_version(tool)
    new_tool_name = get_new_tool_name(tool)
    new_tool_name = new_tool_name == "chef-#{node['enroll']['nodeman_pkg']}" ? node['enroll']['nodeman_pkg'] : new_tool_name
    tool_dir_path = "#{new_resource.chef_tools_dir_path}/#{new_tool_name}"
    current_version_file_path = "#{tool_dir_path}/current_version"
    if platform?('windows')
      current_version_file_path = "#{tool_dir_path}\\current_version"
    end
    shell_out("cat #{current_version_file_path}").stdout.chomp
  end

  def get_new_tool_name(tool_name)
    # Construct the file name as the tgz file name is not same as tool name mentioned in the URL
    case tool_name
    when 'courier-client'
      node['enroll']['runner_pkg']
    when 'inspec_interpreter'
      'inspec-interpreter'
    when node['enroll']['nodeman_pkg']
      "chef-#{node['enroll']['nodeman_pkg']}"
    else
      tool_name
    end
  end

  def get_tool_pkg_name(tool, latest_version)
    os = node['kernel']['os']
    machine = node['kernel']['machine']

    # Determine the architecture and raise an error for unsupported architectures
    pkg_arch = if os == 'Darwin' && machine == 'x86_64'
                 'darwin-amd64'
               elsif os == 'Darwin' && machine == 'arm64'
                 'darwin-arm64'
               elsif os == 'GNU/Linux' && (machine == 'x86_64' || machine == 'i386')
                 'linux-amd64'
               elsif os == 'GNU/Linux' && machine == 'arm64'
                 'linux-arm64'
               elsif os == 'Windows' && machine == 'x86_64'
                 'windows-386'
               else
                 raise "Unsupported architecture: #{node['cpu']['architecture']}"
               end
    "#{get_new_tool_name(tool)}-#{latest_version}-#{pkg_arch}.tar.gz"
  end

  def is_tool_installed(tool)
    new_tool_name = get_new_tool_name(tool)
    new_tool_name = new_tool_name == "chef-#{node['enroll']['nodeman_pkg']}" ? node['enroll']['nodeman_pkg'] : new_tool_name
    tool_bin_path = "#{new_resource.chef_tools_dir_path}/#{new_tool_name}/#{new_tool_name}"
    if platform?('windows')
      tool_bin_path = "#{new_resource.chef_tools_dir_path}\\#{new_tool_name}\\#{new_tool_name}"
    end
    ::File.exist?(tool_bin_path)
  end
end

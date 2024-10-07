action_class do
  def install_hab_full
    download_and_extract_hab_package
    install_and_configure_hab
  end

  def install_node_mgmt_full
    bash 'nodeman-installation' do
      code <<-EOH
      set -euo pipefail

      AGENT_BLDR_ORIGIN=${AGENT_BLDR_ORIGIN:="chef-platform"}
      AGENT_BLDR_CHANNEL=${AGENT_BLDR_CHANNEL:="stable"}
      NODE_AGENT_PKG="#{node['enroll']['nodeman_pkg']}"

      # Install the node agent first (load is somehow not picking from non stable channel)
      sudo -E hab pkg install "${AGENT_BLDR_ORIGIN}/${NODE_AGENT_PKG}" --channel "${AGENT_BLDR_CHANNEL}"
      EOH
      action :run
      not_if "hab pkg list --all | grep \"chef-platform/#{node['enroll']['nodeman_pkg']}\""
    end

    manage_nodeman_config_file

    bash 'load_nodman_svc' do
      code <<-EOH
      hab svc load chef-platform/#{node['enroll']['nodeman_pkg']} --force
      hab svc start chef-platform/#{node['enroll']['nodeman_pkg']}
      EOH
      action :run
      not_if "hab svc status chef-platform/#{node['enroll']['nodeman_pkg']} | awk \'NR==2 {print $4}\' | grep \"up\""
    end
  end

  def download_and_extract_hab_package
    hab_package_tgz = 'hab-download-linux.tar.gz'

    directory new_resource.working_dir_path do
      recursive true
    end

    remote_file "#{new_resource.working_dir_path}/#{hab_package_tgz}" do
      source "#{new_resource.chef_platform_url}:#{new_resource.api_port}/node/enrollment/v1/static/habdownload/#{hab_package_tgz}"
      action :create
    end

    directory "#{new_resource.working_dir_path}/hab_package"

    bash 'extract_hab' do
      code <<-EOH
        tar -xvf #{new_resource.working_dir_path}/#{hab_package_tgz} -C #{new_resource.working_dir_path}
      EOH
      action :run
      not_if { ::File.exist?("#{new_resource.working_dir_path}/hab-x86_64-linux.tar.gz") }
    end

    bash 'extract_hab_bin' do
      code <<-EOH
        tar -xvzf #{new_resource.working_dir_path}/hab-x86_64-linux.tar.gz -C #{new_resource.working_dir_path}/hab_package --strip-component 1
      EOH
      action :run
      not_if { ::File.exist?("#{new_resource.working_dir_path}/hab_package/hab") }
    end
  end

  def install_and_configure_hab
    bash 'copy_hab_to_usr_bin' do
      code <<-EOH
        install -v #{new_resource.working_dir_path}/hab_package/hab /usr/bin/hab
      EOH
      action :run
      not_if { ::File.exist?('/usr/bin/hab') }
    end

    bash 'install_core_cacerts' do
      code <<-EOH
        export HAB_LICENSE=accept
        export HAB_NONINTERACTIVE=true
        hab pkg install core/cacerts
      EOH
      action :run
      not_if 'hab pkg path core/cacerts'
    end

    bash 'install_core_hab_sup' do
      code <<-EOH
        export HAB_LICENSE=accept
        export HAB_NONINTERACTIVE=true
        hab pkg install core/hab-sup
      EOH
      action :run
      not_if 'hab pkg path core/hab-sup'
    end

    ca_cert_pkg_path = shell_out('hab pkg path core/cacerts').stdout
    ssl_cert_file = "#{ca_cert_pkg_path.chop}/ssl/cert.pem"

    template '/etc/systemd/system/hab-sup.service' do
      cookbook node['enroll']['cookbook_name']
      source 'hab-sup.service.erb'
      variables(
        ssl_cert_file: lazy { ssl_cert_file }
      )
    end

    service 'hab-sup' do
      action [:enable, :start]
      notifies :run, 'bash[wait_till_hab_sup_is_up]', :immediately
    end

    bash 'wait_till_hab_sup_is_up' do
      code <<-EOH
        until sudo hab svc status > /dev/null 2>&1; do
          sleep 1
        done
      EOH
      action :nothing
    end
  end
end

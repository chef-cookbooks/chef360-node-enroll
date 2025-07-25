action_class do
  def install_hab_full
    chef_platform_url = new_resource.chef_platform_url
    api_port = new_resource.api_port
    working_dir_path = new_resource.working_dir_path

    # Create the working directory
    directory "#{working_dir_path}\\extracted_hab" do
      recursive true
      action :create
    end

    # Download the Habitat ZIP file
    remote_file "#{working_dir_path}\\hab.zip" do
      source "#{chef_platform_url}:#{api_port}/node/enrollment/v1/static/habdownload/hab-download-windows.zip"
      ssl_verify_mode new_resource.ssl_verify_mode
      action :create
    end

    # Extract the hab ZIP file
    powershell_script 'extract_hab' do
      code <<-EOH
        Add-Type -A 'System.IO.Compression.FileSystem'
        [System.IO.Compression.ZipFile]::ExtractToDirectory('#{working_dir_path}\\hab.zip', '#{working_dir_path}')
        $hab_zip_file_path = Get-ChildItem -Path '#{working_dir_path}\\hab-*.zip'
        Expand-Archive -Path $hab_zip_file_path -DestinationPath "#{working_dir_path}\\extracted_hab"
        $items = Get-ChildItem "#{working_dir_path}\\extracted_hab"

        # Check if there's only one item in the directory
        if ($items.Count -eq 1 -and $items[0].PSIsContainer) {
            # Move the contents of the first item to the destination directory
            $sourcePath = Join-Path $items[0].FullName "*"
            Move-Item -Path $sourcePath -Destination "#{working_dir_path}\\extracted_hab" -Force
            # Remove the empty directory
            Remove-Item -Path $items[0].FullName -Force -Recurse
        }
        New-Item -ItemType File -Path '#{working_dir_path}\\extracted.txt' | Out-Null
      EOH
      action :run
      not_if { ::File.exist?("#{working_dir_path}\\extracted.txt") }
    end

    # Install Habitat
    powershell_script 'install_hab' do
      code <<-EOH
        $habPath = Join-Path $env:ProgramData Habitat
        if (!(Test-Path -Path $habPath\* -PathType Leaf)) {
          New-Item $habPath -ItemType Directory | Out-Null
          $sourcePath = "#{working_dir_path}\\extracted_hab\\*"
          Copy-Item $sourcePath -Destination $habPath

          $pathArray = $env:PATH -split ';'

          # Check if the habPath is already in the PATH
          if ($pathArray -notcontains $habPath) {
              # If not, add the path to the PATH variable
              $env:PATH += ";$habPath"
              Write-Host "Path added to PATH: $habPath"
          } else {
              Write-Host "Path already exists in PATH: $habPath"
          }

          $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
          if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
              $machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
              $machinePath = "$machinePath;$habPath"
              [System.Environment]::SetEnvironmentVariable("PATH", $machinePath, "Machine")
          } else {
              Write-Warning "Not running with Administrator privileges. Unable to add $habPath to PATH!"
              Write-Warning "Either rerun as Administrator or manually add $habPath to your PATH in order to run hab in another shell session."
          }
        } else {
          Write-Host "Habitat is already installed at $habPath"
        }
      EOH
      action :run
      not_if { ::File.directory?(::File.join(ENV['ProgramData'], 'Habitat')) }
      # notifies :run, 'powershell_script[verify_hab]', :immediately
    end

    create_hab_cert

    # Configure Hab
    # powershell_script 'configure_hab' do
    #   code <<-EOH
    #     $env:HAB_LICENSE = "accept"
    #     $env:HAB_NONINTERACTIVE = "true"
    #     $env:HAB_BLDR_URL = "#{new_resource.hab_builder_url}"

    #     $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")

    #     hab pkg path core/windows-service
    #     if ($LASTEXITCODE -ne 0) {
    #         Write-Host "Installing core/windows-service"
    #         hab pkg install core/windows-service
    #         hab pkg install core/hab-sup
    #         if ($LASTEXITCODE -ne 0) {
    #             Write-Host "Failed to install 'core/windows-service'."
    #             Exit 1
    #         }
    #     }

    #     $serviceStatus = Get-Service -Name "Habitat"
    #     if ($serviceStatus.Status -ne "Running") {
    #         Start-Service -Name "Habitat"
    #         Write-Host "Habitat service started."
    #     } else {
    #         Write-Host "Habitat service is already running."
    #     }
    #   EOH
    #   not_if <<-EOH
    #     $serviceStatus = Get-Service -Name "Habitat" -ErrorAction SilentlyContinue
    #     if ($serviceStatus) {
    #         $serviceStatus.Status -eq "Running"
    #     } else {
    #         $false
    #     }
    #   EOH
    #   live_stream true
    # returns [0]
    # end

        # Configure Hab
    powershell_script 'configure_hab' do
      code <<-EOH
        $env:HAB_LICENSE = "accept"
        $env:HAB_NONINTERACTIVE = "true"
        $env:HAB_BLDR_URL = "#{new_resource.hab_builder_url}"

        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")

        hab pkg path core/windows-service
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Installing core/windows-service"
            hab pkg install core/windows-service
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Failed to install 'core/windows-service'."
                Exit 1
            }
            Write-Host "Installing core/hab-sup"
            hab pkg install core/hab-sup
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Failed to install 'core/hab-sup'."
                Exit 1
            }
        }

        $serviceStatus = Get-Service -Name "Habitat" -ErrorAction SilentlyContinue
        if ($serviceStatus -and $serviceStatus.Status -ne "Running") {
            try {
                Start-Service -Name "Habitat" -ErrorAction Stop
                Write-Host "Habitat service started successfully."
            } catch {
                Write-Host "Failed to start Habitat service: $($_.Exception.Message)"
                Exit 1
            }
        } elseif ($serviceStatus) {
            Write-Host "Habitat service is already running."
        } else {
            Write-Host "Habitat service not found."
            Exit 1
        }
      EOH
      not_if <<-EOH
        $serviceStatus = Get-Service -Name "Habitat" -ErrorAction SilentlyContinue
        if ($serviceStatus) {
            $serviceStatus.Status -eq "Running"
        } else {
            $false
        }
      EOH
      live_stream true
      returns [0]
    end
    
  end

  def install_node_mgmt_full
    powershell_script 'install_node_management_agent' do
      code <<-EOH
        $env:HAB_LICENSE = "accept"
        $env:HAB_NONINTERACTIVE = "true"
        $env:HAB_BLDR_URL = "#{new_resource.hab_builder_url}"
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")

        $agentBldrOrigin = "chef-platform"
        $agentBldrChannel = "stable"
        $agentPkgName = "#{node['enroll']['nodeman_pkg']}"

        hab pkg install "$agentBldrOrigin/$agentPkgName" --channel "$agentBldrChannel"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to install '$agentBldrOrigin/$agentPkgName'."
            Exit 1
        }
      EOH
      not_if <<-EOH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        (hab pkg list --all) -match "chef-platform/#{node['enroll']['nodeman_pkg']}"
      EOH
      live_stream true
      returns [0]
    end

    manage_nodeman_config_file

    # powershell_script 'load_nodman_svc' do
    #   code <<-EOH
    #     $env:HAB_LICENSE = "accept"
    #     $env:HAB_NONINTERACTIVE = "true"
    #     $env:HAB_BLDR_URL = "#{new_resource.hab_builder_url}"
    #     $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")

    #     hab svc load chef-platform/#{node['enroll']['nodeman_pkg']} --force
    #     hab svc start chef-platform/#{node['enroll']['nodeman_pkg']}
    #   EOH
    #   action :run
    #   not_if <<-EOH
    #     $status = hab svc status chef-platform/#{node['enroll']['nodeman_pkg']}
    #     if ($status -match 'up') {
    #       return $true
    #     } else {
    #       return $false
    #     }
    #   EOH
    # end

    powershell_script 'load_nodman_svc' do
      code <<-EOH
        $env:HAB_LICENSE = "accept"
        $env:HAB_NONINTERACTIVE = "true"
        $env:HAB_BLDR_URL = "#{new_resource.hab_builder_url}"
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")

        Write-Host "Loading chef-platform/#{node['enroll']['nodeman_pkg']} service..."
        hab svc load chef-platform/#{node['enroll']['nodeman_pkg']} --force
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to load chef-platform/#{node['enroll']['nodeman_pkg']} service."
            Exit $LASTEXITCODE
        }

        Write-Host "Starting chef-platform/#{node['enroll']['nodeman_pkg']} service..."
        hab svc start chef-platform/#{node['enroll']['nodeman_pkg']}
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to start chef-platform/#{node['enroll']['nodeman_pkg']} service."
            Exit $LASTEXITCODE
        }

        Write-Host "Successfully loaded and started chef-platform/#{node['enroll']['nodeman_pkg']} service."
      EOH
      action :run
      only_if <<-EOH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        try {
          $status = hab svc status chef-platform/#{node['enroll']['nodeman_pkg']} 2>$null
          if ($LASTEXITCODE -eq 0 -and $status -match 'up') {
            Write-Host "Service chef-platform/#{node['enroll']['nodeman_pkg']} is already running."
            return $false
          } else {
            Write-Host "Service chef-platform/#{node['enroll']['nodeman_pkg']} is not running."
            return $true
          }
        } catch {
          Write-Host "Service chef-platform/#{node['enroll']['nodeman_pkg']} is not loaded or not running."
          return $true
        }
      EOH
      live_stream true
      returns [0]
    end
  end
end

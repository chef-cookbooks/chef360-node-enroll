# Cookbook:: chef360-node-enroll

# The Chef InSpec reference, with examples and extensive documentation, can be
# found at https://docs.chef.io/inspec/resources/

control 'che360-services' do
  title 'Ensure required Chef platform services are running and enabled'
  desc 'Checks status of node-management-agent, courier-runner, and chef-gohai services'

  %w(
    node-management-agent
    courier-runner
    chef-gohai
  ).each do |svc|
    describe service(svc) do
      it { should be_installed }
      it { should be_enabled }
      it { should be_running }
    end
  end
end

control 'chef360-courier-log-check' do
  impact 1.0
  title 'Verify courier-runner log contains expected data'
  desc 'Check that the courier-runner log contains the string "failed to dequeue"'

  # Skip this control on Windows systems
  only_if('Not running on Windows') do
    !os.windows?
  end

  # Set log path
  log_path = '/etc/chef_platform/tools/courier-runner/logs/courier-log'

  only_if('Courier log file exists') do
    file(log_path).exist?
  end

  describe file(log_path) do
    its('content') { should include 'failed to dequeue' }
  end
end

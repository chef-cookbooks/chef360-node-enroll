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

# Cookbook:: chef360-node-enroll

# The Chef InSpec reference, with examples and extensive documentation, can be
# found at https://docs.chef.io/inspec/resources/

control 'chef360-habitat-services' do
  impact 1.0
  title 'Verify specific Habitat services are up and running'
  desc 'Ensure specific Habitat services are in desired=up and state=up within a timeout'

  required_services = %w(
    chef-platform/courier-runner
    chef-platform/chef-gohai
    chef-platform/node-management-agent
  )

  max_wait = 60
  interval = 5
  waited = 0
  service_status = {}

  until waited >= max_wait
    output = command('hab svc status').stdout
    lines = output.lines.reject { |l| l.strip.empty? || l.start_with?('package') }

    lines.each do |line|
      fields = line.split
      name = fields[0].split('/')[0..1].join('/')
      if required_services.include?(name)
        service_status[name] = { desired: fields[2], actual: fields[3] }
      end
    end

    break if required_services.all? { |s| service_status[s]&.values == %w(up up) }

    sleep interval
    waited += interval
  end

  required_services.each do |svc|
    describe "Habitat service #{svc}" do
      it "should have desired=up and state=up within #{max_wait} seconds" do
        status = service_status[svc]
        expect(status).not_to be_nil, "Service #{svc} not found in hab svc status output"
        expect(status[:desired]).to eq('up') if status
        expect(status[:actual]).to eq('up') if status
      end
    end
  end
end

control 'chef360-courier-log-check' do
  impact 1.0
  title 'Verify courier-runner log contains expected data'
  desc 'Check that the courier-runner log contains the string "failed to dequeue"'
  
  # Set log path based on OS
  log_path = os.windows? ? 'C:\\hab\\svc\\courier-runner\\logs\\courier-log' : '/hab/svc/courier-runner/logs/courier-log'
  
  only_if("Courier log file exists") do
    file(log_path).exist?
  end

  describe file(log_path) do
    its('content') { should include 'failed to dequeue' }
  end
end

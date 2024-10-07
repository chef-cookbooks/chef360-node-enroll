default['enroll']['node_role_id'] = '633daf9a-7aa8-4851-9b7d-88b12be9a87b'
default['enroll']['tools'] = %w(chef-gohai courier-client inspec_interpreter node-management-agent restart-interpreter shell-interpreter chef-client-interpreter)
default['enroll']['interpreters'] = %w(shell-interpreter inspec-interpreter restart-interpreter chef-client-interpreter)
default['enroll']['nodeman_pkg'] = 'node-management-agent'
default['enroll']['runner_pkg'] = 'courier-runner'
default['enroll']['gohai_pkg'] = 'chef-gohai'
default['enroll']['cookbook_name'] = 'chef-cookbook-enroll'

default['enroll']['node_guid_file'] = if platform?('windows')
                                        "c:\\hab\\svc\\#{node['enroll']['nodeman_pkg']}\\data\\node_guid"
                                      else
                                        "/hab/svc/#{node['enroll']['nodeman_pkg']}/data/node_guid"
                                      end

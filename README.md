### Overview

The `node_management_enroll` custom resource is designed to streamline the process of enrolling nodes into a Chef-360 platform. This resource automates the configuration and setup required to ensure nodes are properly registered and managed by the Chef platform's node management service.

### Enrollment and Enrollment Levels
Enrollment is the process that enables Chef 360 to interact with and potentially manage your node. The enrollment status level determines the extent of management and control Chef 360 has over the node. This level indicates the type and degree of management capabilities available.

The `node_management_enroll` resource supports two levels of enrollment:

1. **Full Enrollment**: Chef 360 has both Node Management and Habitat installed on the node, running as a Habitat supervised service. This level allows Chef 360 to manage skill credentials, settings, installation, upgrades, and removal.

2. **Partial Enrollment**: Chef 360 has Node Management running on the node, but as a native service (not under the Habitat supervisor or package manager). This level allows for the detection of native skills and skill credential management but does not support skill installation, upgrades, or configuration. This is suitable for nodes that do not support Habitat but require a specific skill like Courier Runner.

### Resource Parameters

| Parameter          | Description                                                                                                      | Valid Value                                           | Default Value                  |
|--------------------|----------------------------------------------------------------------------------------------------------------|-------------------------------------------------------|--------------------------------|
| `chef_platform_url`| The fully qualified domain name (FQDN) URL for the Chef 360 platform.                                             | A FQDN which must be accessible from the client node. | None                           |
| `api_port`         | The API port configured in the Chef 360 platform.                                                                | A valid port number.                                  | `31000`                        |
| `access_key`       | Access key for secure communication with Chef 360. Store securely (e.g., Encrypted Chef data bags, Vault).      | Valid token                                           | None                           |
| `secret_key`       | Secret key for secure communication with Chef 360. Store securely (e.g., Encrypted Chef data bags, Vault).      | Valid token                                           | None                           |
| `cohort_id`        | A UUID representing a cohort. It provides all required skills and settings to the assigned node.               | UUID                                                  | None                           |
| `hab_builder_url`  | URL for the Chef Habitat builder in your organization.                                                          | Valid URL                                             | `https://bldr.habitat.sh`      |
| `working_dir_path` | Temporary working directory path where all required builds are downloaded. Specify a valid path based on the OS.| A valid directory with read and write permission.     | `/tmp`                         |
| `root_ca`          | Root certificate used for SSL/TLS communication. Only required for secure env                                                                | A valid root certificate                              | None                           |
| `ssl_verify_mode`  | Defines the SSL verification mode. Use `verify_none` for self-signed certificates and `verify_peer` for legitimate certificates requiring verification. | `:verify_none`, `:verify_peer` | `:verify_none` |
| `upgrade_skills`   | For partial enrollment. If true, checks for the latest skill version and installs it if found.                 | `'true'` or `'false'`                                 | `false`                        |

### Obtaining `root_ca`
1) **Self-Signed Environment**: Run the below command on the host where Chef 360 server is installed:
   ```sh
   kubectl get secret --namespace <<namespace>> common-generated-certs -o jsonpath="{.data['ca\.crt']}" | base64 -d
   ```
2) **Custom Certificate**: Use the same `root_ca` that was used while configuring the Chef 360 API/UI section.
3) **Chef 360 SaaS**: Contact the Progress IT Team for obtaining the root CA.



### Example Usage

```ruby
node_management_enroll 'Enroll Node' do
  chef_platform_url '<CHEF-360-FQDN>'
  enroll_type 'full/partial'
  api_port '<API_PORT>'
  access_key '<ACCESS_KEY>'
  secret_key '<SECRET_KEY>'
  cohort_id '<COHORT_ID>'
  hab_builder_url '<HABITAT_BUILDER_URL>'
  working_dir_path '<VALID_DIR_PATH>'
  root_ca node['enroll']['root_ca']
  ssl_verify_mode <:verify_peer,:verify_peer>
  upgrade_skills <false/true>
end
```



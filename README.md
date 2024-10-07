### Overview

The `node_management_enroll` custom resource is designed to streamline the process of enrolling nodes into a Chef-360 platform. This resource automates the configuration and setup required to ensure nodes are properly registered and managed by the Chef platform's node management service.

### Enrollment and Enrollment Levels
Enrollment is the process that enables Chef 360 to interact with and potentially manage your node. The enrollment status level determines the extent of management and control Chef 360 has over the node. This level indicates the type and degree of management capabilities available.

The `node_management_enroll` resource supports two levels of enrollment:

1. **Full Enrollment**: Chef 360 has both Node Management and Habitat installed on the node, running as a Habitat supervised service. This level allows Chef 360 to manage skill credentials, settings, installation, upgrades, and removal.

2. **Partial Enrollment**: Chef 360 has Node Management running on the node, but as a native service (not under the Habitat supervisor or package manager). This level allows for the detection of native skills and skill credential management but does not support skill installation, upgrades, or configuration. This is suitable for nodes that do not support Habitat but require a specific skill like Courier Runner.

### Resource Parameters

| Parameter          | Description                                                                                                      | Valid Value                                           | Default Value                  |
|--------------------|------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------|--------------------------------|
| `chef_platform_url`| The fully qualified domain name (FQDN) URL for the Chef 360 platform.                                             | A FQDN which must be accessible from the client node. | None                           |
| `api_port`         | The API port configured in the Chef 360 platform.                                                                 | A valid port number.                                  | `31000`                        |
| `access_key`       | Access key for secure communication with Chef 360. Store securely (e.g., Encrypted Chef data bags, Vault).       | valid token                                                  | None                           |
| `secret_key`       | Secret key for secure communication with Chef 360. Store securely (e.g., Encrypted Chef data bags, Vault).       | valid token                                                  | None                           |
| `cohort_id`        | A UUID representing a cohort. It provides all required skills and settings to the assigned node.                | UUID                                                  | None                           |
| `hab_builder_url`  | URL for the Chef Habitat builder in your organization.                                                           | Valid URL                                             | `https://bldr.habitat.sh`      |
| `working_dir_path` | Temporary working directory path where all required builds are downloaded. Specify a valid path based on the OS. | A valid directory with read and write permission.     | `/tmp`                         |
| `upgrade_skills`   | For partial enrollment. If true, checks for the latest skill version and installs it if found.                  | `'true'` or `'false'`                                 | `false`                        |


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
  upgrade_skills false
end
```
## Using the `node_management_enroll` Custom Resource

The `node_management_enroll` custom resource is designed to simplify the process of enrolling nodes into a Chef-managed environment. Follow these steps to use this resource:

### 1. Upload the Custom Resource Cookbook to the Chef Server

First, upload the cookbook containing the `node_management_enroll` resource to the Chef server. Replace `COOKBOOK_DIR_PATH` with the path to your cookbook directory:

```bash
knife cookbook upload chef-cookbook-enroll --cookbook-path COOKBOOK_DIR_PATH
```

### 2. Create a Wrapper Cookbook

Next, create a wrapper cookbook to manage the custom resource's usage. In the `metadata.rb` file of your wrapper cookbook, add the following dependency to include the `chef-cookbook-enroll` cookbook:

```ruby
depends 'chef-cookbook-enroll', '~> 1.0.0'
```

### 3. Update the Wrapper Cookbook's Recipe with the Custom Resource

In your wrapper cookbook's recipe, configure the `node_management_enroll` resource as follows:

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
  upgrade_skills false
end
```

Replace the placeholders with the actual values for your environment.

### 4. Push the Wrapper Cookbook or Policy to the Chef Server

Depending on whether you are using a role or a policy, follow the appropriate steps:

#### a) If Using a Role

Push the wrapper cookbook to the Chef server using the following command:

```bash
knife cookbook upload YOUR_WRAPPER_COOKBOOK_NAME --cookbook-path WRAPPER_COOKBOOK_DIR_PATH
```

#### b) If Using a Policy

Push the policy to the Chef server using the following commands:

```bash
chef install
chef push <POLICY_GROUP> <POLICY_NAME>
```

### 5. Apply the Wrapper Cookbook in Role/Policy

Finally, ensure that the wrapper cookbook is included in your node's run-list by adding it to a role or policy. This will execute the `node_management_enroll` resource during the Chef run.


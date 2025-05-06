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
3) **Chef 360 SaaS**: Copy of the Chef 360 SaaS public key and add it to your wrapper cookbook:

  ```
  -----BEGIN CERTIFICATE-----
  MIIDXzCCAkegAwIBAgILBAAAAAABIVhTCKIwDQYJKoZIhvcNAQELBQAwTDEgMB4
  GA1UECxMXR2xvYmFsU2lnbiBSb290IENBIC0gUjMxEzARBgNVBAoTCkdsb2JhbF
  NpZ24xEzARBgNVBAMTCkdsb2JhbFNpZ24wHhcNMDkwMzE4MTAwMDAwWhcNMjkwM
  zE4MTAwMDAwWjBMMSAwHgYDVQQLExdHbG9iYWxTaWduIFJvb3QgQ0EgLSBSMzET
  MBEGA1UEChMKR2xvYmFsU2lnbjETMBEGA1UEAxMKR2xvYmFsU2lnbjCCASIwDQY
  JKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMwldpB5BngiFvXAg7aEyiie/QV2Ec
  WtiHL8RgJDx7KKnQRfJMsuS+FggkbhUqsMgUdwbN1k0ev1LKMPgj0MK66X17YUh
  hB5uzsTgHeMCOFJ0mpiLx9e+pZo34knlTifBtc+ycsmWQ1z3rDI6SYOgxXG71uL
  0gRgykmmKPZpO/bLyCiR5Z2KYVc3rHQU3HTgOu5yLy6c+9C7v/U9AOEGM+iCK65
  TpjoWc4zdQQ4gOsC0p6Hpsk+QLjJg6VfLuQSSaGjlOCZgdbKfd/+RFO+uIEn8rU
  AVSNECMWEZXriX7613t2Saer9fwRPvm2L7DWzgVGkWqQPabumDk3F2xmmFghcCA
  wEAAaNCMEAwDgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0O
  BBYEFI/wS3+oLkUkrk1Q+mOai97i3Ru8MA0GCSqGSIb3DQEBCwUAA4IBAQBLQNv
  AUKr+yAzv95ZURUm7lgAJQayzE4aGKAczymvmdLm6AC2upArT9fHxD4q/c2dKg8
  dEe3jgr25sbwMpjjM5RcOO5LlXbKr8EpbsU8Yt5CRsuZRj+9xTaGdWPoO4zzUhw
  8lo/s7awlOqzJCK6fBdRoyV3XpYKBovHd7NADdBj+1EbddTKJd+82cEHhXXipa0
  095MJ6RMG3NzdvQXmcIfeg7jLQitChws/zyrVQ4PkX4268NXSb7hLi18YIvDQVE
  TI53O9zJrlAGomecsMx86OyXShkDOOyyGeMlhLxS67ttVb9+E7gUJTb0o2HLO02
  JQZR7rkpeDMdmztcpHWD9f
  -----END CERTIFICATE-----
  ```

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
  ssl_verify_mode <:verify_none/:verify_peer>
  upgrade_skills <false/true>
end
```
      

### Generating Access Key and Secret Key

To generate an access key and secret key, follow the steps below.

> **Note:**  
> Ensure you run this command on a Chef Workstation that is registered with the Chef 360 server.

#### Command

Use the following CLI command to generate an access key and secret key:

```bash
chef-platform-auth-cli user-account self create-token --body '{"expiration": "EXPIRATION_DATE", "name": "ANY_TOKEN_NAME"}' --profile VALID_PROFILE_NAME
```

#### Example Response

```json
{
  "item": {
    "accessKey": "6QIUKP4WIXD4RVAF0BQ3",
    "expiration": "2027-12-31T11:42:23-05:00",
    "id": "bcba5b7a-fb0b-4a62-b442-7ba7bda5e05a",
    "name": "CI-CD Token",
    "role": {
      "id": "5fcb0235-1e56-4ece-8857-404a5d39a290",
      "name": "tenant-admin"
    },
    "secretKey": "x6aCg1NckQoLsQnere26fmGgD0RiWOrf4RNXBhlg"
  }
}
```

#### Important Notes

- The `--profile` you use in the command must have the **node-manager** role assigned to it.
- Replace `EXPIRATION_DATE` with the desired expiration timestamp (e.g., `2027-12-31T11:42:23-05:00`).
- Replace `ANY_TOKEN_NAME` with a meaningful token name for easy identification.
- Replace `VALID_PROFILE_NAME` with the name of a valid profile configured on your workstation.
 



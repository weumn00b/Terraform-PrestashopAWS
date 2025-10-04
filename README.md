# Terraform AWS PrestaShop Deployment Script

## Overciew

This Python script automates the deployment of a **PrestaShop e-comm website** on AWS using Terraform.

- **EC2 Instance** – Runs the PrestaShop Docker image.
- **RDS Instance** – Provides a managed MySQL database for PrestaShop.
- **S3 Bucket** – Stores media assets (images, etc.) for the website.

The script allows configuration of variables like region, instance type, and database creds


---


## Features

- Prompts the user for variable input, also has an option for default values
- Updates the `terraform.tfvars` file, which holds the values 
- Runs Terraform commands (`init`, `plan`, `apply`) to deploy the infrastructure
- Supports Windows and Linux environments
- Enables repeatable deployments using Infrastructure-as-Code (IaC)


---


## Prerequisites

Before running the script, install and configure the following:

1. **Python 3**
   verify you have Python installed with
   ```
   python --version
   ```

2. **Terraform**
   Install Terraform from this [link](https://developer.hashicorp.com/terraform/install)
   Ensure that Terraform has been added to your PATH
   
3. **AWS CLI**
   Configure AWS CLI with an IAM user that has permissions for
   - EC2
   - RDS
   - S3
   Configure AWS using
  ```
  aws configure
  ```

Note: You'll need to know your AMI ID for the machine you want to use, you'll also need to make a keypair for SSH in EC2 before creating the machine.


---


## Usage
1. Clone the repository
2. Open a terminal in the script directory
3. Run the script using:
   ```
   python3 runTerraform.py
   ```
4. Enter the variables or press Enter to use defaults
5. This will output:
   - Public IP for the Web Server
   - RDS Endpoint address
   - S3 Bucket Name

6. I haven't finished the Security part of this project, so in order to connect RDS and EC2 containers, you'll have to manually add the connection through the AWS web portal.

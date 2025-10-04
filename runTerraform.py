#Liam Browning

import subprocess
import os

#Entering changes

print("Enter your Terraform variables (press Enter to use default):")

aws_region = input("AWS Region [us-east-2]: ") or "us-east-2"
key_name = input("Key Name [keypair]: ") or "keypair"
instance_type = input("Instance Type [t2.micro]: ") or "t2.micro"
db_username = input("DB Username [admin]: ") or "admin"
db_password = input("DB Password [password]: ") or "password"
s3_bucket_name = input("S3 Bucket Name [prestashop-media]: ") or "prestashop-media"
ami_id = input("AMI ID [ami-077b630ef539aa0b5]: ") or "ami-077b630ef539aa0b5"
#Creating terraform.tfvars

tfvars_content = f"""
aws_region      = "{aws_region}"
key_name        = "{key_name}"
instance_type   = "{instance_type}"
db_username     = "{db_username}"
db_password     = "{db_password}"
s3_bucket_name  = "{s3_bucket_name}"
ami_id          = "{ami_id}"
"""

os.chdir("AWS-Prestashop-Image")

tfvars_file = "terraform.tfvars"
with open(tfvars_file, "w") as f:
    f.write(tfvars_content)
#Changes tfvars if needed
print(f"{tfvars_file} created/updated successfully.")

#function to run a terraform command
def run_terraform(command):
    print(f"\nRunning: {command}\n")
    # Start the process
    process = subprocess.Popen(
        command, shell=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT
    )
    
    # Print output line by line as it comes
    for line in iter(process.stdout.readline, ''):
        print(line, end='')  # end='' prevents adding extra newlines

    process.stdout.close()
    process.wait()

    if process.returncode != 0:
        print(f"\nCommand failed with exit code {process.returncode}")
        exit(1)

# Initialize Terraform
run_terraform("terraform init")

# Plan Terraform deployment
run_terraform("terraform plan -var-file=terraform.tfvars")

# Apply Terraform deployment
run_terraform("terraform apply -auto-approve -var-file=terraform.tfvars")

print("\nTerraform deployment complete!")

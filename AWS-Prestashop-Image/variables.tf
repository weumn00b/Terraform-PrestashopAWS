//Liam Browning

variable "aws_region" { default = "us-east-2" }
variable "key_name" { default = "keypair" }
variable "instance_type" { default = "t2.micro" }
variable "db_username" { default = "admin" }
variable "db_password" { default = "password" }
variable "s3_bucket_name" { default = "prestashop-media" }
variable "ami_id" { default = "ami-077b630ef539aa0b5"}
variable "public_ip" { default = "0.0.0.0" }

//This is the main VPC that will be tied to RDS and EC2

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

//Allows traffic out to the internet

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

//Creating the Public Subnet for the E-Comm server

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-2b"
  map_public_ip_on_launch = true
}

//Creation of a routing table, this sends any IPv4 traffic out to the internet. Any traffic that is sent through to the Private VPC is routed by AWS internally

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

//Assigns the routing table to the public subnet only

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

//Creation of the Private subnet (where RDS will sit)

resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-2b"
  map_public_ip_on_launch = false
}

//There needs to be 2 private subnets for a subnet group to work in AWS

resource "aws_subnet" "private2_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = false
}

//RDS needs to be in a subnet group for higher availability, balancing workloads, and to actually control the networking portion.

resource "aws_db_subnet_group" "rds_subnets" {
  name       = "rds-subnet-group"
  subnet_ids = [aws_subnet.private_subnet.id, aws_subnet.private2_subnet.id]

  tags = {
    Name = "RDS Subnet Group"
  }
}

resource "aws_s3_bucket" "media_bucket" {
  bucket = var.s3_bucket_name
}

//Creating EC2 secuity group that allows HTTP, HTTPS from anywhere and SSH from a specific public ip (yours)

resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "Allow HTTP, HTTPS, SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.public_ip}/32"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

//This allows traffic connecting to MySQL only if the instance has the security group for EC2

resource "aws_security_group" "rds_sg" {
  name        = "rds_sg"
  description = "Allow MySQL from EC2 only"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = [aws_security_group.ec2_sg] //ensures EC2 security group exists first
}

//Creates the prestashop database in a RDS, assigns it to the VPC and places it in the RDS Subnet group

resource "aws_db_instance" "prestashop_db" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  db_name              = "prestashop"
  username             = var.db_username
  password             = var.db_password
  skip_final_snapshot  = true
  publicly_accessible  = false
  availability_zone    = "us-east-2b"
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnets.name
}


//creates the IAM role needed to access the S3 Bucket

resource "aws_iam_role" "ec2_s3_access" {
  name = "ec2-s3-access"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_s3" {
  role       = aws_iam_role.ec2_s3_access.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

//Creates the EC2 prestashop image and assigns it to the correct public subnet, it also gives it the correct key pair, IAM role, and security group. It assigns a Public IP to the instance as well.

resource "aws_instance" "prestashop_ec2" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = aws_subnet.public_subnet.id
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true   # ensures a public IP is assigned
  

//This user_data will install docker and run the prestashop image
  
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              service docker start
              usermod -aG docker ec2-user
              docker run -d --name prestashop -p 80:80 -e DB_SERVER=${aws_db_instance.prestashop_db.address} -e DB_USER=${var.db_username} -e DB_PASSWORD='${var.db_password}' prestashop/prestashop:8.1
              EOF
//Can expand this later to use HTTPS when running prestashop
  tags = { Name = "PrestaShopServer" }
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-profile"
  role = aws_iam_role.ec2_s3_access.name
}

//Liam Browning

variable "aws_region" { default = "us-east-2" }
variable "key_name" { default = "keypair" }
variable "instance_type" { default = "t2.micro" }
variable "db_username" { default = "admin" }
variable "db_password" { default = "password" }
variable "s3_bucket_name" { default = "prestashop-media" }
variable "ami_id" { default = "ami-077b630ef539aa0b5"}
variable "public_ip" { default = "0.0.0.0" }

#VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

#Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-2b"
  map_public_ip_on_launch = true
}

# Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate route table with subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Private Subnet (no IGW route)
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-2b"
  map_public_ip_on_launch = false
}

# Private Subnet 2
resource "aws_subnet" "private2_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = false
}

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

//Creates security groups
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

  depends_on = [aws_security_group.ec2_sg] //ensures EC2 SG exists first
}

//Creates the prestashop database in a RDS

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


//This is supposed to allow EC2 to connect to the RDS instance, I havben't got it to work yet and have to manually add the RDS and EC2 together. Will need to mess around with the virtual network I think.



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

resource "aws_instance" "prestashop_ec2" {
  ami           = var.ami_id
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

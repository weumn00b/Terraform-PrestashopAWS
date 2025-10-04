//Liam Browning

resource "aws_s3_bucket" "media_bucket" {
  bucket = var.s3_bucket_name
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
}

//You can leave this if you want, but I like assigning my Public IP to the ingress rules so only I can connect.

resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "Allow HTTP, HTTPS, SSH"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["97.94.60.81/32"]
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
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"] 
    }
}

//This is supposed to allow EC2 to connect to the RDS instance, I havben't got it to work yet and have to manually add the RDS and EC2 together. Will need to mess around with the virtual network I think.

resource "aws_security_group" "rds_sg" {
  name        = "rds_sg"
  description = "Allow MySQL from EC2 only"
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }
  egress {
from_port = 0
to_port = 0
protocol = "-1"
cidr_blocks = ["0.0.0.0/0"] 
}
}
//This will give your EC2 instance access to your S3 Bucket

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
  ami           = "ami-example"  //Change this to the correct AMI
  instance_type = var.instance_type
  key_name      = var.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  security_groups = [aws_security_group.ec2_sg.name]

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

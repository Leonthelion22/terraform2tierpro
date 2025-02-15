# Provider and version and the region
provider "aws" {
  region = "us-east-1"
}

# Define and create the VPC with a CIDR Block
resource "aws_vpc" "leonvpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Public Subnets (for the EC2 instance)
resource "aws_subnet" "publicsub1" {
  vpc_id                  = aws_vpc.leonvpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "Publicsub1"
  }
}

resource "aws_subnet" "publicsub2" {
  vpc_id                  = aws_vpc.leonvpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "Publicsub2"
  }
}

# Private Subnets (For the Relational DataBase)
resource "aws_subnet" "privatesub1" {
  vpc_id            = aws_vpc.leonvpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "Privatesub1"
  }
}

resource "aws_subnet" "privatesub2" {
  vpc_id            = aws_vpc.leonvpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "Privatesub2"
  }
}

# Creating the Internet Gateway (for public subnet access)
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.leonvpc.id
}

# Creating a Route Table for the public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.leonvpc.id
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

# Associate  the route table with public subnets
resource "aws_route_table_association" "publicassociation1" {
  subnet_id      = aws_subnet.publicsub1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "publicassociation2" {
  subnet_id      = aws_subnet.publicsub2.id
  route_table_id = aws_route_table.public.id
}

# Security Group for EC2 instances
resource "aws_security_group" "webserver_secg" {
  name        = "webserver_secg"
  description = "Allow inbound traffic HTTP and SSH"
  vpc_id      = aws_vpc.leonvpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
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

# Security Group for Relational Data Base MySQL
resource "aws_security_group" "relationaldatabase_secg" {
  name        = "relationaldatabase_secg"
  description = "Allow inbound traffic MySQL"
  vpc_id      = aws_vpc.leonvpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.publicsub1.cidr_block, aws_subnet.publicsub2.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance 1 (EC2 instance in Public Subnet 1)
resource "aws_instance" "leonEC21" {
  ami                    = "ami-085ad6ae776d8f09c" # Update with a proper Amazon Linux AMI
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.publicsub1.id
  vpc_security_group_ids = [aws_security_group.webserver_secg.id]

  tags = {
    Name = "leonEC21"
  }

  user_data = <<-EOT
              #!/bin/bash
              yum install -y httpd
              service httpd start
              chkconfig httpd on
              EOT
}

# EC2 Instance 2 (EC2 instance in Public Subnet 2)
resource "aws_instance" "leonEC22nd" {
  ami                    = "ami-085ad6ae776d8f09c" # Update with a proper Amazon Linux AMI
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.publicsub2.id
  vpc_security_group_ids = [aws_security_group.webserver_secg.id]

  tags = {
    Name = "leonEC22nd"
  }

  user_data = <<-EOT
              #!/bin/bash
              yum install -y httpd
              service httpd start
              chkconfig httpd on
              EOT
}

# Create RelationalDatabase MySQL Instance 
resource "aws_db_instance" "mydb" {
  identifier             = "mydb"
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "mydatabase"
  username               = "admin"
  password               = "password9999"
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.relationaldatabase_secg.id]
  multi_az               = false
  storage_type           = "gp2"
  skip_final_snapshot    = true
}

# Data Base Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "main-subnet-group"
  subnet_ids = [aws_subnet.privatesub1.id, aws_subnet.privatesub2.id]

  tags = {
    Name = "Main DataBase Subnet Group"
  }
}

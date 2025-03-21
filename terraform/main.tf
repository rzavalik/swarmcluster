terraform {
  backend "s3" {
    bucket = "zavalik-terraformstate"
    key    = "swarm-cluster/state/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

# SSH Shared Key
resource "aws_s3_object" "ssh_key" {
  bucket = "zavalik-terraformstate"
  key    = "swarm-cluster/id_rsa"            
  acl    = "private"               
  source = "~/.ssh/id_rsa"         
}

# Create the VPC
resource "aws_vpc" "new_vpc" {
  cidr_block = "10.1.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "SwarmCluster"
  }
}

# Create subnets for the VPC
resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.new_vpc.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "SwarmCluster-SubnetA"
  }
}

resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.new_vpc.id
  cidr_block              = "10.1.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags = {
    Name = "SwarmCluster-SubnetB"
  }
}

resource "aws_route_table" "swarm-rtb" {
  vpc_id = aws_vpc.new_vpc.id
  tags = {
    Name = "SwarmCluster RTB"
  }
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.swarm-rtb.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.swarmgtw.id
}

resource "aws_route_table_association" "main_az1" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.swarm-rtb.id
}

resource "aws_route_table_association" "main_az2" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.swarm-rtb.id
}

resource "aws_internet_gateway" "swarmgtw" {
  vpc_id = aws_vpc.new_vpc.id
  tags = {
    Name = "SwarmCluster-IGW"
  }
}

# Create a Security Group for the EC2 instances
resource "aws_security_group" "swarmallow_sg" {
  name        = "swarmallow_sg"
  description = "Allow all inbound traffic"
  vpc_id      = aws_vpc.new_vpc.id

  # Allow SSH access (port 22) from your IP range
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all ports and protocols inside the VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.new_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create IAM Role for EC2 Instances to interact with S3
resource "aws_iam_role" "swarm_ec2_role" {
  name = "swarm-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect    = "Allow"
        Sid       = ""
      },
    ]
  })
}

# Attach a policy to the role to allow ECR access
resource "aws_iam_policy" "swarm_ecr_policy" {
  name        = "SwarmECRPolicy"
  description = "Allows EC2 instances to pull images from ECR"
  
  # Policy to allow access to ECR actions
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetRepositoryPolicy",
          "ecr:BatchGetImage",
          "ecr:ListImages",
          "ecr:GetDownloadUrlForLayer
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the ECR access policy to the EC2 role
resource "aws_iam_role_policy_attachment" "swarm_ec2_role_policy" {
  role       = aws_iam_role.swarm_ec2_role.name
  policy_arn = aws_iam_policy.swarm_ecr_policy.arn
}

resource "aws_iam_instance_profile" "swarm_ec2_instance_profile" {
  name = "swarm-ec2-instance-profile"
  role = aws_iam_role.swarm_ec2_role.name
}

# IAM Policy for Node1 (write access to S3)
resource "aws_iam_policy" "swarm_managernode_s3_read_policy" {
  name        = "SwarmNode1S3WritePolicy"
  description = "Allow Node1 to write the Swarm join token to S3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "s3:PutObject"
        Effect   = "Allow"
        Resource = "arn:aws:s3:::zavalik-terraformstate/swarm-cluster/*"
      },
    ]
  })
}

# IAM Policy for Node2 and Node3 (read access to S3)
resource "aws_iam_policy" "swarm_workernode_s3_read_policy" {
  name        = "SwarmNode2S3ReadPolicy"
  description = "Allow Node2 and Node3 to read the Swarm join token from S3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "s3:GetObject"
        Effect   = "Allow"
        Resource = "arn:aws:s3:::zavalik-terraformstate/swarm-cluster/*"
      },
    ]
  })
}

# Attach write policy to Node1 IAM role
resource "aws_iam_role_policy_attachment" "node1_s3_write_policy_attachment" {
  policy_arn = aws_iam_policy.swarm_managernode_s3_read_policy.arn
  role       = aws_iam_role.swarm_ec2_role.name
}

# Attach read policy to Node2 and Node3 IAM roles
resource "aws_iam_role_policy_attachment" "node2_s3_read_policy_attachment" {
  policy_arn = aws_iam_policy.swarm_workernode_s3_read_policy.arn
  role       = aws_iam_role.swarm_ec2_role.name
}

# EC2 Instances for Swarm (Control Plane and Data Planes)
resource "aws_instance" "swarm_node_1" {
  ami                    = var.ec2_ami
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.subnet_a.id
  vpc_security_group_ids = [aws_security_group.swarmallow_sg.id]
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.swarm_ec2_instance_profile.name

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y

              # Instala docker e pre-requisitos
              sudo apt install -y apt-transport-https ca-certificates curl software-properties-common unzip
              sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
              sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" -y
              sudo apt update -y
              sudo apt install -y docker-ce
              sudo systemctl start docker
              sudo systemctl enable docker

              sudo usermod -aG docker $USER
              sudo newgrp docker

              sudo chown root:docker /var/run/docker.sock
              sudo chmod 660 /var/run/docker.sock

              # Instala o AWS CLI
              sudo curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              sudo unzip -q awscliv2.zip
              sudo ./aws/install

              # Ativa a chave SSH
              sudo mkdir -p /home/ubuntu/.ssh
              sudo aws s3 cp s3://zavalik-terraformstate/swarm-cluster/id_rsa /home/ubuntu/.ssh/id_rsa
              sudo chmod 600 /home/ubuntu/.ssh/id_rsa
              sudo chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa
              sudo systemctl restart ssh

              # Autentica na ECR
              sudo aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 588738580149.dkr.ecr.us-east-1.amazonaws.com

              # Inicializa o cluster Swarm
              sudo docker swarm init --advertise-addr $(hostname -I | awk '{print $1}')
              SWARM_TOKEN=$(sudo docker swarm join-token worker -q)
              echo "$SWARM_TOKEN" | aws s3 cp - s3://zavalik-terraformstate/swarm-cluster/SwarmToken.txt

              # Instala e faz download do YAML
              sudo apt install -y docker-compose

              sudo wget https://raw.githubusercontent.com/rzavalik/swarmcluster/refs/heads/master/swarm/docker-compose.yml
              sudo wget https://raw.githubusercontent.com/rzavalik/swarmcluster/refs/heads/master/swarm/start.sh
              EOF

  depends_on = [aws_security_group.swarmallow_sg]

  tags = {
    Name = "SwarmCluster-MasterNode"
  }
}

resource "aws_instance" "swarm_node_2" {
  ami                    = var.ec2_ami
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.subnet_a.id
  vpc_security_group_ids = [aws_security_group.swarmallow_sg.id]
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.swarm_ec2_instance_profile.name

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y

              # Instala docker e pre-requisitos
              sudo apt install -y apt-transport-https ca-certificates curl software-properties-common unzip
              sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
              sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" -y
              sudo apt update -y
              sudo apt install -y docker-ce
              sudo systemctl start docker
              sudo systemctl enable docker

              sudo usermod -aG docker $USER
              sudo newgrp docker

              sudo chown root:docker /var/run/docker.sock
              sudo chmod 660 /var/run/docker.sock

              # Instala o AWS CLI
              sudo curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              sudo unzip -q awscliv2.zip
              sudo ./aws/install

              # Ativa a chave SSH
              sudo mkdir -p /home/ubuntu/.ssh
              sudo aws s3 cp s3://zavalik-terraformstate/swarm-cluster/id_rsa /home/ubuntu/.ssh/id_rsa
              sudo chmod 600 /home/ubuntu/.ssh/id_rsa
              sudo chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa
              sudo systemctl restart ssh

              # Autentica na ECR
              sudo aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 588738580149.dkr.ecr.us-east-1.amazonaws.com

              # Inicializa o cluster Swarm
              SWARM_TOKEN=$(aws s3 cp s3://zavalik-terraformstate/swarm-cluster/SwarmToken.txt -)
              sudo docker swarm join --token $SWARM_TOKEN ${aws_instance.swarm_node_1.private_ip}:2377

              EOF

  depends_on = [aws_instance.swarm_node_1, aws_security_group.swarmallow_sg]

  tags = {
    Name = "SwarmCluster-Worker2"
  }
}

resource "aws_instance" "swarm_node_3" {
  ami                    = var.ec2_ami
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.subnet_b.id
  vpc_security_group_ids = [aws_security_group.swarmallow_sg.id]
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.swarm_ec2_instance_profile.name

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y

              # Instala docker e pre-requisitos
              sudo apt install -y apt-transport-https ca-certificates curl software-properties-common unzip
              sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
              sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" -y
              sudo apt update -y
              sudo apt install -y docker-ce
              sudo systemctl start docker
              sudo systemctl enable docker

              sudo usermod -aG docker $USER
              sudo newgrp docker

              sudo chown root:docker /var/run/docker.sock
              sudo chmod 660 /var/run/docker.sock

              # Instala o AWS CLI
              sudo curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              sudo unzip -q awscliv2.zip
              sudo ./aws/install

              # Ativa a chave SSH
              sudo mkdir -p /home/ubuntu/.ssh
              sudo aws s3 cp s3://zavalik-terraformstate/swarm-cluster/id_rsa /home/ubuntu/.ssh/id_rsa
              sudo chmod 600 /home/ubuntu/.ssh/id_rsa
              sudo chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa
              sudo systemctl restart ssh

              # Autentica na ECR
              sudo aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 588738580149.dkr.ecr.us-east-1.amazonaws.com

              # Inicializa o cluster Swarm
              SWARM_TOKEN=$(aws s3 cp s3://zavalik-terraformstate/swarm-cluster/SwarmToken.txt -)
              sudo docker swarm join --token $SWARM_TOKEN ${aws_instance.swarm_node_1.private_ip}:2377

              EOF

  depends_on = [aws_instance.swarm_node_1, aws_security_group.swarmallow_sg]

  tags = {
    Name = "SwarmCluster-Worker3"
  }
}

# Create an Application Load Balancer (ALB)
resource "aws_lb" "joke_lb" {
  name                       = "SwarmCluster-Joke-LB"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.swarmallow_sg.id]
  subnets                    = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
  enable_deletion_protection = false
}

# Create a Target Group for JokePresentation (Port 80)
resource "aws_lb_target_group" "jokepresentation_target_group" {
  name     = "SwarmCluster-Joke-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.new_vpc.id

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    protocol            = "HTTP"
    port                = 80
    matcher             = "200-299"
  }

  depends_on = [aws_instance.swarm_node_1, aws_instance.swarm_node_2, aws_instance.swarm_node_3]
}

# Attach Node2 to the JokePresentation Target Group
resource "aws_lb_target_group_attachment" "node2_jokepresentation" {
  target_group_arn = aws_lb_target_group.jokepresentation_target_group.arn
  target_id        = aws_instance.swarm_node_2.id
  port             = 80
}

# Attach Node3 to the JokePresentation Target Group
resource "aws_lb_target_group_attachment" "node3_jokepresentation" {
  target_group_arn = aws_lb_target_group.jokepresentation_target_group.arn
  target_id        = aws_instance.swarm_node_3.id
  port             = 80
}

# ALB Listener
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.joke_lb.arn
  port              = "80"
  protocol          = "HTTP"

  # Route all other traffic to JokePresentation (port 80)
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jokepresentation_target_group.arn
  }

  depends_on = [aws_lb.joke_lb]
}

output "alb_dns_name" {
  value = aws_lb.joke_lb.dns_name
  description = "The DNS name of the ALB"
}
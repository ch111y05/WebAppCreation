resource "aws_vpc" "hashi_vpc" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }
}

resource "aws_subnet" "hashi_private_subnet" {
  vpc_id                  = aws_vpc.hashi_vpc.id
  cidr_block              = "10.123.1.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "us-west-2a"

  tags = {
    Name = "dev-private"
  }
}

resource "aws_subnet" "hashi_public_subnet" {
  vpc_id                  = aws_vpc.hashi_vpc.id
  cidr_block              = "10.123.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-2a"

  tags = {
    Name = "dev-public"
  }
}

resource "aws_subnet" "hashi_public_subnet_2" {
  vpc_id                  = aws_vpc.hashi_vpc.id
  cidr_block              = "10.123.3.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-2b"

  tags = {
    Name = "dev-public-2"
  }
}

resource "aws_internet_gateway" "hashi_internet_gateway" {
  vpc_id = aws_vpc.hashi_vpc.id

  tags = {
    Name = "dev-igw"
  }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "hashi_nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.hashi_public_subnet.id

  tags = {
    Name = "dev-nat"
  }
}

resource "aws_route_table" "hashi_private_rt" {
  vpc_id = aws_vpc.hashi_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.hashi_nat_gateway.id
  }

  tags = {
    Name = "dev_private_rt"
  }
}

resource "aws_route_table_association" "hashi_private_assoc" {
  subnet_id      = aws_subnet.hashi_private_subnet.id
  route_table_id = aws_route_table.hashi_private_rt.id
}

resource "aws_security_group" "hashi_web_sg" {
  name        = "web-sg"
  description = "Security group for web server"
  vpc_id      = aws_vpc.hashi_vpc.id

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

resource "aws_security_group_rule" "allow_alb" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.hashi_web_sg.id
  source_security_group_id = tolist(aws_lb.web_alb.security_groups)[0]
}

resource "aws_security_group_rule" "allow_alb_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.hashi_web_sg.id
  source_security_group_id = tolist(aws_lb.web_alb.security_groups)[0]
}

resource "aws_key_pair" "hashi_auth" {
  key_name   = "hashikey"
  public_key = file("~/.ssh/hashikey.pub")
}

resource "aws_iam_role" "ssm_role" {
  name = "SSMRoleForEC2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
  role       = aws_iam_role.ssm_role.name
}

resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "SSMInstanceProfile"
  role = aws_iam_role.ssm_role.name
}

resource "aws_instance" "dev_node" {
  instance_type          = "t2.micro"
  ami                    = data.aws_ami.server_ami.id
  key_name               = aws_key_pair.hashi_auth.id
  vpc_security_group_ids = [aws_security_group.hashi_web_sg.id]
  subnet_id              = aws_subnet.hashi_private_subnet.id

user_data = <<-EOF
              <powershell>
              Install-WindowsFeature -name Web-Server -IncludeManagementTools

              # Create a basic HTML page for the example
              $htmlContent = @"
              <html>
              <head>
                  <title>Sample Web App</title>
              </head>
              <body>
                  <h1>Welcome to the Sample Web App on IIS</h1>
                  <p>This is a sample page deployed via Terraform.</p>
              </body>
              </html>
              "@

              # Write the content to the default IIS folder
              $htmlContent | Out-File -Encoding ASCII C:\inetpub\wwwroot\index.html

              # Optionally, if you have a .NET app package, you would deploy it here.
              </powershell>
EOF

  tags = {
    Name = "dev-node"
  }

  root_block_device {
    # volume_size = 8
  }
}

resource "aws_lb" "web_alb" {
  name               = "dev-web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.hashi_web_sg.id]
  subnets            = [aws_subnet.hashi_public_subnet.id, aws_subnet.hashi_public_subnet_2.id]

  enable_deletion_protection = false
  enable_cross_zone_load_balancing = true
}

resource "aws_lb_target_group" "web_tg" {
  name     = "dev-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.hashi_vpc.id

  health_check {
    enabled = true
    interval = 30
    path = "/"
    timeout = 5
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}
locals {
  bucket_name   = "employee-photo-bucket-msd-${random_id.this.dec}"
  accout_number = "725049844389"
}

#Retrieve the list of AZs in the current AWS region
data "aws_availability_zones" "available" {}
data "aws_region" "current" {}

resource "random_id" "this" {
  byte_length = 5
}

## Creating employment directory app VPC and the subnets
resource "aws_vpc" "emp_dir_vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name      = var.vpc_name
    Region    = data.aws_region.current.name
    Terraform = true
  }
}

# create an internet gateway and attached to the vpc
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.emp_dir_vpc.id
  tags = {
    Name      = "my_emp_igw"
    Region    = data.aws_region.current.name
    Terraform = true
  }
}

#Deploy the public subnets
resource "aws_subnet" "public_subnets" {
  for_each                = var.public_subnets
  vpc_id                  = aws_vpc.emp_dir_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value)
  availability_zone       = tolist(data.aws_availability_zones.available.names)[each.value]
  map_public_ip_on_launch = true

  tags = {
    Name      = each.key
    Region    = data.aws_region.current.name
    Terraform = "true"
  }
}
#Deploy the private subnets
resource "aws_subnet" "private_subnets" {
  for_each          = var.private_subnets
  vpc_id            = aws_vpc.emp_dir_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value)
  availability_zone = tolist(data.aws_availability_zones.available.names)[each.value]

  tags = {
    Name      = each.key
    Region    = data.aws_region.current.name
    Terraform = "true"
  }
}

# create route table for internet access
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.emp_dir_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name      = "emp_public_rt"
    Region    = data.aws_region.current.name
    Terraform = "true"
  }
}

#Create route table associations for public subnets
resource "aws_route_table_association" "public" {
  depends_on     = [aws_subnet.public_subnets]
  route_table_id = aws_route_table.public_route_table.id
  for_each       = aws_subnet.public_subnets
  subnet_id      = each.value.id
}

# create route table for private subnets
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.emp_dir_vpc.id
  tags = {
    Name      = "emp_private_rt"
    Region    = data.aws_region.current.name
    Terraform = "true"
  }
}

#Create route table associations for private subnets
resource "aws_route_table_association" "private" {
  depends_on     = [aws_subnet.private_subnets]
  route_table_id = aws_route_table.private_route_table.id
  for_each       = aws_subnet.private_subnets
  subnet_id      = each.value.id
}

# allow http and https port security group
resource "aws_security_group" "emp_allow_http" {
  name        = "emp_allow_http"
  description = "Allow http/https inbound traffic"
  vpc_id      = aws_vpc.emp_dir_vpc.id

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "http from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name      = "emp_allow_http"
    Region    = data.aws_region.current.name
    Terraform = "true"
  }
}

# selecting ami for instances
data "aws_ami" "amazon-2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "image-id"
    values = ["ami-051f7e7f6c2f40dc1"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

}

data "aws_iam_instance_profile" "iam_profile_s3dynamo" {
  name = "S3DynamoDBFullAccessRole"
}

resource "tls_private_key" "ec2_pkey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "emp_kp" {
  key_name   = "emp_key" # Create a "myKey" to AWS!!
  public_key = tls_private_key.ec2_pkey.public_key_openssh

  provisioner "local-exec" { # Create a "myKey.pem" to your computer!!
    command = "echo '${tls_private_key.ec2_pkey.private_key_pem}' > ./myKey.pem && chmod 400 ./myKey.pem"
  }
}
module "ec2-instance" {
  source = "terraform-aws-modules/ec2-instance/aws"
  name          = "emp_app_ec2"
  ami           = data.aws_ami.amazon-2023.id
  instance_type = "t2.micro"
  key_name = aws_key_pair.emp_kp.key_name
  vpc_security_group_ids = [aws_security_group.emp_allow_http.id]
  subnet_id              = aws_subnet.public_subnets["my_public_subnet_1"].id
  iam_instance_profile   = data.aws_iam_instance_profile.iam_profile_s3dynamo.name
  user_data              = <<EOF
#!/bin/bash -ex
wget https://aws-tc-largeobjects.s3-us-west-2.amazonaws.com/DEV-AWS-MO-GCNv2/FlaskApp.zip
unzip FlaskApp.zip
cd FlaskApp/
yum -y install python3-pip
pip install -r requirements.txt
yum -y install stress
export PHOTOS_BUCKET=${local.bucket_name}
export AWS_DEFAULT_REGION=${data.aws_region.current.name}
export DYNAMO_MODE=on
FLASK_APP=application.py /usr/local/bin/flask run --host=0.0.0.0 --port=80
EOF

  tags = {
    Name      = "emp_app_ec2"
    Region    = data.aws_region.current.name
    Terraform = "true"
  }
}



module "s3-bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"
  bucket = local.bucket_name
  acl    = "private"

  control_object_ownership = true
  object_ownership         = "ObjectWriter"
  attach_policy            = true
  /* the other method to enter a policy in like this:
policy                   = jsonencode(
  {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowS3ReadAccess",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::725049844389:role/S3DynamoDBFullAccessRole"
            },
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::${local.bucket_name}",
                "arn:aws:s3:::${local.bucket_name}/*"
            ]
        }
    ]
})
*/

  policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowS3ReadAccess",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${local.accout_number}:role/S3DynamoDBFullAccessRole"
            },
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::${local.bucket_name}",
                "arn:aws:s3:::${local.bucket_name}/*"
            ]
        }
    ]
}
EOF
  tags = {
    Name      = local.bucket_name
    Region    = data.aws_region.current.name
    Terraform = "true"
  }
}

resource "aws_dynamodb_table" "employees" {
  name           = "Employees"
  hash_key       = "id"
  read_capacity  = 1
  write_capacity = 1

  attribute {
    name = "id"
    type = "S"
  }
  tags = {
    Name      = "dynamodb_Table_Employees"
    Region    = data.aws_region.current.name
    Terraform = "true"
  }
}

resource "aws_lb" "emp_alb" {
  name               = "emp-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.emp_allow_http.id]
  subnets            = [for subnet in aws_subnet.public_subnets : subnet.id]

  tags = {
    Name      = "emp_alb"
    Region    = data.aws_region.current.name
    Terraform = "true"
  }
}

resource "aws_lb_target_group" "emp_tg" {
  name     = "emp-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.emp_dir_vpc.id
  health_check {
    enabled             = true
    interval            = 40
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 30
    protocol            = "HTTP"
    matcher             = "200-399"
  }
  tags = {
    Name      = "emp-lb-tg"
    Region    = data.aws_region.current.name
    Terraform = "true"
  }
}

resource "aws_lb_listener" "emp_front_end" {
  load_balancer_arn = aws_lb.emp_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.emp_tg.arn
  }
}
resource "aws_lb_target_group_attachment" "emp_tg_attach" {
  target_group_arn = aws_lb_target_group.emp_tg.arn
  target_id        = module.ec2-instance.id
  port             = 80
}

resource "aws_launch_template" "emp_launch_temp" {
  name        = "app-launch-template"
  description = "A web server for the employee directory application"

  provisioner "local-exec" {
    command = "sed -e 's/bucket_name/${local.bucket_name}/g;s/region_name/${data.aws_region.current.name}/g'  ./user_data.sh.template > user_data.sh"
  }

  iam_instance_profile {
    name = data.aws_iam_instance_profile.iam_profile_s3dynamo.name
  }

  image_id = data.aws_ami.amazon-2023.id

  instance_initiated_shutdown_behavior = "terminate"

  instance_type = "t2.micro"

  key_name = aws_key_pair.emp_kp.key_name

  vpc_security_group_ids = [aws_security_group.emp_allow_http.id]
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name      = "emp_launch_temp"
      Region    = data.aws_region.current.name
      Terraform = "true"
    }
  }

  user_data = filebase64("./user_data.sh")
}

resource "aws_autoscaling_group" "emp_asg" {
  name                      = "app_asg"
  max_size                  = 4
  min_size                  = 2
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 2
  force_delete              = true
  vpc_zone_identifier       = [for subnet in aws_subnet.public_subnets : subnet.id]
  launch_template {
    id      = aws_launch_template.emp_launch_temp.id
    version = "$Latest"
  }
}
# Create a new load balancer attachment
resource "aws_autoscaling_attachment" "emp_as_attach" {
  autoscaling_group_name = aws_autoscaling_group.emp_asg.id
  lb_target_group_arn    = aws_lb_target_group.emp_tg.arn
}

resource "aws_autoscaling_policy" "emp_asg_policy" {
  name = "emp_asg_policy"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.emp_asg.name
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  target_value = 60.0
  }
}
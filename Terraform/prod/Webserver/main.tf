# Terraform Config file (main.tf). This has provider block (AWS) and config for provisioning one EC2 instance resource.  

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.27"
    }
  }

  required_version = ">=0.14"
}
provider "aws" {
  region  = "us-east-1"
}

data "terraform_remote_state" "prod_net_tfstate" { // This is to use Outputs from Remote State
  backend = "s3"
  config = {
    bucket = "prod-behzad-bucket"             // Bucket from where to GET Terraform State
    key    = "network/terraform.tfstate" // Object name in the bucket to GET Terraform State
    region = "us-east-1"                     // Region where bucket created
  }
}

# Data source for AMI id
data "aws_ami" "latest_amazon_linux" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Data source for availability zones in us-east-1
data "aws_availability_zones" "available" {
  state = "available"
}

# Define tags locally
locals {
  default_tags = merge(var.default_tags, { "env" = var.env })
  name_prefix  = "${var.prefix}"
}

resource "aws_instance" "public_instance" {
  count                       = length(data.terraform_remote_state.prod_net_tfstate.outputs.public_subnet_ids)
  ami                         = data.aws_ami.latest_amazon_linux.id
  instance_type               = lookup(var.instance_type, var.env)
  key_name                    = aws_key_pair.keyName.key_name    # because we used count in key_name so we have to give it's index
  security_groups             = [aws_security_group.public_instance_SG.id]
  subnet_id                   = data.terraform_remote_state.prod_net_tfstate.outputs.public_subnet_ids[count.index] # it use s3/dev/network/terraform.tfstate => outputs. you can also see it in Network/output.tf file
  associate_public_ip_address = true
  # # 1st way
  #user_data  = file("${path.module}/install_httpd.sh")
  # user_data  =<<-EOF
  #           #!/bin/bash
  #           sudo yum -y update
  #           sudo yum -y install httpd
  #           echo "<h1>Welcome to ACS730 Week 6!" >  /var/www/html/index.html
  #           sudo systemctl start httpd
  #           sudo systemctl enable httpd
  #       EOF

  # # 2nd way
  # user_data = file("${path.module}/install_httpd.sh")

 # 3rd way
  # format msut be .sh.tpl  we can use variables(env, prefix) inside the script      templatefile("address",{variables})
  # it just install userdata in Instance 1 and 3
  user_data = count.index == 0 || count.index == 2 ? templatefile("${path.module}/install_httpd.sh.tpl",
    {
      env    = upper(var.env),
      prefix = upper(var.prefix),
      name   = "Behzad Rajabalipour"
    }
  ) : null

  root_block_device { # it will encrypt it if it is in env=test
    encrypted = var.env == "test" ? true : false
  }

  lifecycle { # lifecycle will create a new instance before destroy previous one
    create_before_destroy = true
  }

  # Dynamic tags
  tags = merge(
    local.default_tags,
    count.index == 1
      ? { 
          Name = "Bastion VM webserver${count.index + 1}",
          Role = "Bastion VM"
          Type = "type1"
        }
      : { 
          Name = "webserver${count.index + 1}",
          Type = contains([3], count.index) ? "type1" : null
        }
  )
}

resource "aws_instance" "private_instance" {
  count                       = length(data.terraform_remote_state.prod_net_tfstate.outputs.private_subnet_ids)
  ami                         = data.aws_ami.latest_amazon_linux.id
  instance_type               = lookup(var.instance_type, var.env)
  key_name                    = aws_key_pair.keyName.key_name    # because we used count in key_name so we have to give it's index
  security_groups             = [aws_security_group.private_instance_SG.id]
  subnet_id                   = data.terraform_remote_state.prod_net_tfstate.outputs.private_subnet_ids[count.index] # it use s3/dev/network/terraform.tfstate => outputs. you can also see it in Network/output.tf file

  root_block_device { # it will encrypt it if it is in env=test
    encrypted = var.env == "test" ? true : false
  }

  lifecycle { # lifecycle will create a new instance before destroy previous one
    create_before_destroy = true
  }

  # Dynamic tags
  tags = merge(
    local.default_tags,
    count.index == 0
      ? {
          Name = "Webserver5"
        }
      : {
          Name = "VM6"
        }
  )
}

resource "aws_key_pair" "keyName" {
  key_name   = var.keyName
  public_key = file("./${var.keyName}.pub")  # Replace with the path to your public key
}

#security Group
resource "aws_security_group" "public_instance_SG" {
  name        = "allow_http_ssh"
  description = "Allow HTTP and SSH inbound traffic"
  vpc_id      = data.terraform_remote_state.prod_net_tfstate.outputs.vpc_id

  ingress {
    description      = "HTTP from everywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "SSH from everywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = merge(local.default_tags,
    {
      "Name" = "${var.prefix}-public-SG"         # keys should be in ~/.ssh otherwise you can't change their permission with chmod 400
    }
  )
}

resource "aws_security_group" "private_instance_SG" {
  name        = "allow_ssh_icmp"
  description = "Allow SSH and ICMP traffic from a specific VM"
  vpc_id      = data.terraform_remote_state.prod_net_tfstate.outputs.vpc_id

  # Ingress rule for SSH
  ingress {
    description = "Allow SSH from specific VM"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${aws_instance.public_instance[1].private_ip}/32"]  # private_ip(IPV4 private), Allow SSH from the Bastion VM (public VM)
  }

  # Egress rule to allow all outbound traffic
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"    # Allow all egress traffic
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow SSH and ICMP Security Group"
  }
}

# # Elastic IP
# resource "aws_eip" "static_eip" {
#   instance = aws_instance.public_instance.id
#   tags = merge(local.default_tags,
#     {
#       "Name" = "${var.prefix}-eip"
#     }
#   )
# }

# Attach EBS volume
# resource "aws_volume_attachment" "ebs_att" {
#   count       = var.env == "prod" ? 1 : 0
#   device_name = "/dev/sdh"
#   volume_id   = aws_ebs_volume.web_ebs[count.index].id
#   instance_id = aws_instance.public_instance.id
# }

# # Create another EBS volume
# resource "aws_ebs_volume" "web_ebs" {
#   count             = var.env == "prod" ? 1 : 0
#   availability_zone = data.aws_availability_zones.available.names[1]
#   size              = 40

#   tags = merge(local.default_tags,
#     {
#       "Name" = "${var.prefix}-EBS"
#     }
#   )
# }


# Register EC2 Instances to Target Group
resource "aws_lb_target_group_attachment" "tg_attachment" {
  count             = length(aws_instance.public_instance[*].id) - 1  # exclude the last public instance (Webserver4) 
  target_group_arn  = data.terraform_remote_state.prod_net_tfstate.outputs.target_group_arn
  target_id         = aws_instance.public_instance[count.index].id
  port              = 80
}

#----------------------------------------------------------------------
# ASG

# Launch Template for Instances
resource "aws_launch_template" "public_instance_lt" {
  name          = "${var.prefix}-template"
  image_id      = data.aws_ami.latest_amazon_linux.id
  instance_type = lookup(var.instance_type, var.env)
  key_name      = "prodKey"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.public_instance_SG.id]
  }

  user_data = base64encode(file("${path.module}/install_httpd.sh"))

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      local.default_tags,
      {
        "Name" = "${var.prefix}-template"
      }
    )
  }
}

# Auto Scaling Group with Health Check and Target Tracking
resource "aws_autoscaling_group" "public_instance_asg" {
  name                        = "ALB"
  min_size                    = var.asg_min_size
  max_size                    = var.asg_max_size
  desired_capacity            = var.asg_desired_capacity  # Set the desired capacity to 1
  health_check_type           = "ELB"
  force_delete                = true

  launch_template {
    id      = aws_launch_template.public_instance_lt.id
    version = "$Latest"
  }

  vpc_zone_identifier         = slice(
    data.terraform_remote_state.prod_net_tfstate.outputs.public_subnet_ids, 
    0,
    length(data.terraform_remote_state.prod_net_tfstate.outputs.public_subnet_ids) - 1
  )
  target_group_arns           = [data.terraform_remote_state.prod_net_tfstate.outputs.target_group_arn]

  # By enabling group metrics collection, you get increased visibility into the history of your Auto Scaling group,
  # such as changes in the size of the group over time. The metrics are available at a 1-minute granularity 
  # aws console => Monitoring => enable => Enable group metrics collection within CloudWatch
  metrics_granularity = "1Minute" # Enable detailed monitoring (1-minute granularity)
  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]

  tag {
    key                 = "Name"
    value               = "${var.prefix}-asg-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

#---------------------------------------------------------
# TargetTrackingScaling policy
# we can have only one scale in or out TargetTrackingScaling policy
# it will automatically create Cloudwatch alaram for it with CPUUtilization metric

resource "aws_autoscaling_policy" "cpu_scale_out" {
  name                   = "target-tracking-scale-up-policy"
  autoscaling_group_name = aws_autoscaling_group.public_instance_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    target_value             = 60  # Trigger scale-out when CPU usage exceeds 60%
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    disable_scale_in         = true  # Disable scaling in
  }
}

#------------------------------------------
# Simple Scaling policy
# we can have many simple scaling policy

# create cloudwatch alaram with CPUUtilization metric
resource "aws_cloudwatch_metric_alarm" "scale_in_alarm" {
  alarm_name          = "$scale-in-alaram"
  comparison_operator = "LessThanOrEqualToThreshold"         # <=
  
  evaluation_periods  = 2  # data points, Number of periods to evaluate
  datapoints_to_alarm = 2  # data points, Number of data points that must breach the threshold
  
  metric_name         = "CPUUtilization"            # metric name for this alaram
  namespace           = "AWS/EC2"
  period              = 60                  # 60 sec for alaram interval
  statistic           = "Average"
  threshold           = 40                    # CPUUtilization < 40%

  alarm_description   = "Trigger scale-in when CPU utilization is less than 40%"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.public_instance_asg.name
  }
  actions_enabled = true

  alarm_actions = [aws_autoscaling_policy.scale_in_policy.arn]  # Link to scaling policy
}

# create simple scaling policy
resource "aws_autoscaling_policy" "scale_in_policy" {
  name                   = "$simple-scaling-in-policy"
  scaling_adjustment     = -1  # Reduce by 1 instance
  adjustment_type        = "ChangeInCapacity"  # Adjust the number of instances
  cooldown               = 70  # Wait 70 seconds between scaling activities
  autoscaling_group_name = aws_autoscaling_group.public_instance_asg.name
}


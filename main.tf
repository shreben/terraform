# Specify the provider and access details
provider "aws" {
  region = "${var.aws_region}"
}

terraform {
  backend "s3" {
    bucket = "terraform-state-shreben"
    key    = "terraform-state"
    region = "us-west-2"
  }
}

# Create a VPC to launch our instances into
resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
  tags = {
    name = "terraform-vpc"
  }
}

# Create a subnet to launch our instances into
resource "aws_subnet" "private" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = false
}

resource "aws_subnet" "public" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
}

# NAT gateway 
resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "default" {
  allocation_id = "${aws_eip.nat.id}"
  subnet_id     = "${aws_subnet.public.id}"
  depends_on = ["aws_internet_gateway.default"]
}


# Route tables
resource "aws_route_table" "internet" {
  depends_on = ["aws_internet_gateway.default"]
  vpc_id = "${aws_vpc.default.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.default.id}"
  }
}

resource "aws_route_table" "nat" {
  depends_on = ["aws_nat_gateway.default"]
  vpc_id = "${aws_vpc.default.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.default.id}"
  }
}

# Route table association
resource "aws_route_table_association" "internet" {
  subnet_id      = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.internet.id}"
}

resource "aws_route_table_association" "nat" {
  depends_on = ["aws_nat_gateway.default"]
  subnet_id      = "${aws_subnet.private.id}"
  route_table_id = "${aws_route_table.nat.id}"
}

# Default security group
resource "aws_default_security_group" "default" {
  vpc_id = "${aws_vpc.default.id}"

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# A security group for the ELB so it is accessible via the web
resource "aws_security_group" "elb" {
  name        = "terraform-elb"
  description = "terraform - allow 80 from epam"
  vpc_id = "${aws_vpc.default.id}"

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.epam_networks}"]
  }
}

resource "aws_security_group" "bastion" {
  name        = "terraform-bastion"
  description = "terraform - allow 22 from epam"
  vpc_id = "${aws_vpc.default.id}"

  # HTTP access from the VPC
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.epam_networks}"]
  }
}

resource "aws_instance" "web" {
  depends_on = ["aws_route_table_association.nat","aws_instance.bastion"]
  
  connection {
    type = "ssh"
    user = "ec2-user"
    bastion_host = "${aws_instance.bastion.public_ip}"
    bastion_private_key = "${file("ubuntu-box.key")}"
    agent = true
  }

  instance_type = "${var.aws_instance}"
  ami = "${lookup(var.aws_amis, var.aws_region)}"
  key_name = "${var.key_name}"
  subnet_id = "${aws_subnet.private.id}"
  vpc_security_group_ids = ["${aws_default_security_group.default.id}"]
  count = 2

  provisioner "file" {
    source      = "initial_script.sh"
    destination = "/tmp/initial_script.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/initial_script.sh",
      "/tmp/initial_script.sh args",
    ]
  }
}

resource "aws_instance" "bastion" {

  depends_on = ["aws_default_security_group.default","aws_internet_gateway.default"]
  
  connection {
    type = "ssh"
    user = "ec2-user"
    private_key = "${file("ubuntu-box.key")}"
  }

  instance_type = "${var.aws_instance}"
  ami = "${lookup(var.aws_amis, var.aws_region)}"
  key_name = "${var.key_name}"
  vpc_security_group_ids = ["${aws_default_security_group.default.id}","${aws_security_group.bastion.id}"] 
  subnet_id = "${aws_subnet.public.id}"
}

resource "aws_elb" "web" {
  name = "terraform-elb"
  subnets         = ["${aws_subnet.private.id}","${aws_subnet.public.id}"]
  security_groups = ["${aws_default_security_group.default.id}","${aws_security_group.elb.id}"]
  instances       = ["${aws_instance.web.*.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
}
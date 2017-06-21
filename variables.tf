variable "key_name" {
  description = "Desired name of AWS key pair"
  default     = "ubuntu-box"
}

variable "aws_region" {
  description = "AWS region to launch servers."
  default     = "us-west-2"
}

variable "aws_instance" {
    default = "t2.micro"
}

# Ubuntu Precise 12.04 LTS (x64)
variable "aws_amis" {
  default = {
    us-west-2 = "ami-4836a428"
  }
}

# Epam networks
variable "epam_networks" {
    type = "list"
    default = [
        "213.184.243.0/24",
        "217.21.63.0/24",
        "213.184.231.0/24",
        "86.57.255.88/29"
    ]
}
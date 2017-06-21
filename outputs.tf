output "loadbalancer" {
    value = "${aws_elb.web.dns_name}"
}

output "bastion" {
    value = "${aws_instance.bastion.public_ip}"
}

output "web_servers" {
    value = ["${aws_instance.web.*.private_ip}"]
}

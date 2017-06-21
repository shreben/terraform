#!/bin/bash

sudo yum -y update
sudo yum install -y httpd
sudo chkconfig httpd on
sudo service httpd start

[[ ! -f /var/www/html/index.html ]] && sudo touch /var/www/html/index.html

cat <<EOF | sudo tee /var/www/html/index.html
<html>
<body>
<h1>Hello World</h1>
<p>written by Siarhei Hreben</p>
<p/>
<h3>Instance details:</p>
<ul>
<li>instance id:       $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</li>
<li>instance type:     $(curl -s http://169.254.169.254/latest/meta-data/instance-type)</li>
<li>local hostname:    $(curl -s http://169.254.169.254/latest/meta-data/local-hostname)</li>
<li>local ip:          $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)</li>
<li>security groups:   $(curl -s http://169.254.169.254/latest/meta-data/security-groups)</li>
</ul>
</body>
</html>
EOF
sudo service httpd restart

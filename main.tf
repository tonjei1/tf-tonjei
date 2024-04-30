
#key set up
##

resource "tls_private_key" "mykey" {
algorithm = "RSA"
rsa_bits = 4096
}

resource "local_file" "private_key_file" {
filename = "my-public-key2.pem"
content = tls_private_key.mykey.private_key_pem
}

resource "aws_key_pair" "my_public_key" {
key_name = "my-public-key2"
public_key = tls_private_key.mykey.public_key_openssh
}




# Create EC2 instance
resource "aws_instance" "web_instance" {
ami = "ami-04e5276ebb8451442"
instance_type = "t2.micro"
subnet_id = aws_subnet.public_subnet.id
key_name = aws_key_pair.my_public_key.id
vpc_security_group_ids = [aws_security_group.my_sg.id]


provisioner "file" {
    source = "script.sh"
    destination = "/tmp/script.sh"
}

connection {
  type = "ssh"
  user = "ec2_user"
  password = ""
  private_key = local_file.private_key_file.content
  host = self.public_ip
}

provisioner "remote-exec" {
    inline = [
        "chmod 777 /tmp/script.sh",
        "sudo /tmp/script.sh"
    ]
}
}


# Create VPC

##
resource "aws_vpc" "my_vpc" {
cidr_block = "10.0.0.0/16"
}
# Create internet gateway
resource "aws_internet_gateway" "my_igw" {
vpc_id = aws_vpc.my_vpc.id
}
# Create public subnet
resource "aws_subnet" "public_subnet" {
vpc_id = aws_vpc.my_vpc.id
cidr_block = "10.0.0.0/24"
map_public_ip_on_launch = true
}

# Create public subnet
resource "aws_subnet" "private_subnet" {
vpc_id = aws_vpc.my_vpc.id
# cidr_block = "10.0.0.0/24"
}


# Create route table
resource "aws_route_table" "my_public_route_table" {
vpc_id = aws_vpc.my_vpc.id
route {
cidr_block = "0.0.0.0/0"
gateway_id = aws_internet_gateway.my_igw.id
}
}

resource "aws_route_table" "my_private_route_table" {
vpc_id = aws_vpc.my_vpc.id
route {
cidr_block = "0.0.0.0/0"
gateway_id = aws_internet_gateway.my_igw.id
}
}

# Associate route table with public subnet
resource "aws_route_table_association" "public_route_association" {
subnet_id = aws_subnet.public_subnet.id
route_table_id = aws_route_table.my_public_route_table.id
}

# Associate route table with public subnet
resource "aws_route_table_association" "private_route_association" {
subnet_id = aws_subnet.private_subnet.id
route_table_id = aws_route_table.my_private_route_table.id
}
# Create security group
resource "aws_security_group" "my_sg" {
name = "my_sg"
description = "Allow SSH inbound traffic"
vpc_id = aws_vpc.my_vpc.id
ingress {
from_port = 80
to_port = 80
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
}

resource "aws_security_group" "my_sg-db" {
name = "my_sg-db"
description = "Allow Port 80 inbound traffic"
vpc_id = aws_vpc.my_vpc.id
ingress {
from_port =22
to_port = 22
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
}

# Create DB EC2 instance
resource "aws_db_instance" "db-instance1" {
  allocated_storage    = 10
  db_name              = "mydb1"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  username             = "foo"
  password             = "foobarbaz"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true


provisioner "file" {
    source = "db-script.sh"
    destination = "/tmp/db-script.sh"
}

connection {
  type = "ssh"
  user = "ec2_user"
  password = ""
  private_key = local_file.private_key_file.content
  host = self.private_ip
}

provisioner "remote-exec" {
    inline = [
        "chmod 777 /tmp/db-script.sh",
        "sudo /tmp/db-script.sh"
    ]
}
}
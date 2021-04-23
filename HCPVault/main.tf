# Create AWS networks
module "vpc" {
  count = length(var.vpcs)
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 2.0"

  name = var.vpcs[count.index]["name"]
  cidr = var.vpcs[count.index]["cidr"]
  azs = var.vpcs[count.index]["azs"]
  private_subnets = var.vpcs[count.index]["private_subnets"]
  public_subnets = var.vpcs[count.index]["public_subnets"]
  enable_nat_gateway = var.vpcs[count.index]["enable_nat_gateway"]

}
# Create HVN

module "hvn" {
  source = "./hcp_network"
}

# Create peering relationships

module "peering" {
  count = length(var.vpcs)
  source = "./hvn_aws_peering"
  peer_vpc_id = module.vpc[count.index].vpc_id
  hvn_id = module.hvn.hvn_id
}

# Create Vault instance and token

module "vault" {
  source = "./hcp_vault"
  hvn_id = module.hvn.hvn_id
  
}

# Create Consul instance

# Create EC2 instance to access Vault and Consul

data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name = "name"

    values = [
      "amzn-ami-hvm-*-x86_64-gp2",
    ]
  }

  filter {
    name = "owner-alias"

    values = [
      "amazon",
    ]
  }
}

data "http" "my_ip" {
  url = "http://ifconfig.me"
}

resource "aws_security_group" "ec2" {
  count = length(var.vpcs)
  name = "allow_ssh"
  description = "Allow SSH to instance"
  vpc_id = module.vpc[count.index].vpc_id

  ingress  {
    cidr_blocks = [ "${data.http.my_ip.body}/32" ]
    description = "Allow SSH"
    from_port = 22
    protocol = "tcp"
    to_port = 22
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ec2" {
  count = length(var.vpcs)
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  associate_public_ip_address = true
  key_name = var.keyname
  subnet_id   = module.vpc[count.index].public_subnets[0]
  vpc_security_group_ids = [ aws_security_group.ec2[count.index].id ]

}
variable "REGION" {}
variable "AZ" {}
variable "CIDR" {}
variable "SSH_PUB_KEY" {}

variable "TYPE" {
}

variable "AGENTS" {
}

variable "PRICE" {
	default = "0.01"
}

provider "aws" {
  region = "${var.REGION}"
}

resource "random_pet" "demo" {
  prefix    = "drew_demo"
  separator = "_"
}

resource "aws_vpc" "root" {
  cidr_block           = "${var.CIDR}"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"

  tags {
    Name = "${random_pet.demo.id} vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = "${aws_vpc.root.id}"
  cidr_block              = "${var.CIDR}"
  availability_zone       = "${var.REGION}${var.AZ}"
  map_public_ip_on_launch = true

  tags {
    Name = "${random_pet.demo.id} subnet public"
  }
}

resource "aws_internet_gateway" "public" {
  vpc_id = "${aws_vpc.root.id}"

  tags {
    Name = "${random_pet.demo.id} igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.root.id}"

  tags {
    Name = "${random_pet.demo.id} rt public"
  }
}

resource "aws_route" "public_default" {
  route_table_id         = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.public.id}"
}

resource "aws_route_table_association" "public" {
  route_table_id = "${aws_route_table.public.id}"
  subnet_id      = "${aws_subnet.public.id}"
}

resource "aws_security_group" "default" {
  name        = "${random_pet.demo.id}_default"
  description = "${random_pet.demo.id} default sg"
  vpc_id      = "${aws_vpc.root.id}"

  tags {
    Name = "${random_pet.demo.id} default sg"
  }
}

resource "aws_security_group_rule" "self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = "${aws_security_group.default.id}"
}

resource "aws_security_group_rule" "grok_exporter" {
  type              = "ingress"
  from_port         = 8089
  to_port           = 8089
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.default.id}"
}

resource "aws_security_group_rule" "node_exporter" {
  type              = "ingress"
  from_port         = 9100
  to_port           = 9100
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.default.id}"
}

resource "aws_security_group_rule" "https" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.default.id}"
}

resource "aws_security_group_rule" "ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.default.id}"
}

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.default.id}"
}

resource "aws_key_pair" "demo" {
  key_name   = "${random_pet.demo.id}_key"
  public_key = "${file(var.SSH_PUB_KEY)}"
}


### calculate the ID of the latest AMIs

data "aws_caller_identity" "current" {}

data "aws_ami" "agent" {
  filter {
    name   = "name"
    values = ["${random_pet.demo.id}_agent*"]
  }

  most_recent = true
  owners      = ["${data.aws_caller_identity.current.account_id}"]
}

data "aws_ami" "server" {
  filter {
    name   = "name"
    values = ["${random_pet.demo.id}_server*"]
  }

  most_recent = true
  owners      = ["${data.aws_caller_identity.current.account_id}"]
}


### IAM instance role config for server

data "aws_iam_policy_document" "server-policy" {
  statement {
    actions   = ["ec2:Describe*"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "server-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "server" {
  name               = "${random_pet.demo.id}_instance_role"
  assume_role_policy = "${data.aws_iam_policy_document.server-assume-role-policy.json}"
}

resource "aws_iam_role_policy" "server" {
  name   = "spie_demo_instance_policy"
  role   = "${aws_iam_role.server.id}"
  policy = "${data.aws_iam_policy_document.server-policy.json}"
}

resource "aws_iam_instance_profile" "server" {
  name = "${random_pet.demo.id}_instance_profile"
  role = "${aws_iam_role.server.name}"
}

### IAM config for spot fleet control

data "aws_iam_policy_document" "fleet" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["spotfleet.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "fleet" {
  name               = "${random_pet.demo.id}_role"
  assume_role_policy = "${data.aws_iam_policy_document.fleet.json}"
}

resource "aws_iam_policy_attachment" "fleet" {
  name       = "${random_pet.demo.id}_policy_attachment"
  roles      = ["${aws_iam_role.fleet.name}"]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2SpotFleetRole"
}
resource "aws_iam_policy_attachment" "fleet_tag" {
  name       = "${random_pet.demo.id}_policy_attachment_tag"
  roles      = ["${aws_iam_role.fleet.name}"]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2SpotFleetTaggingRole"
}

### spot fleet configuration

resource "aws_spot_fleet_request" "fleet" {
  spot_price      = "${var.PRICE}"
  target_capacity = "${var.AGENTS}"

  iam_fleet_role                      = "${aws_iam_role.fleet.arn}"
  terminate_instances_with_expiration = true

  launch_specification {
    instance_type               = "${var.TYPE}"
    ami                         = "${data.aws_ami.agent.id}"
    key_name                    = "${aws_key_pair.demo.key_name}"
    subnet_id                   = "${aws_subnet.public.id}"
    associate_public_ip_address = true
    vpc_security_group_ids      = ["${aws_security_group.default.id}"]

    tags {
      Name = "${random_pet.demo.id}_spot_agent"
      spire = "demo"
    }
  }
}

### spire-server

resource "aws_instance" "server" {
  tags {
    Name = "${random_pet.demo.id}_spire_server"
  }

  private_ip                  = "10.71.0.10"
  key_name                    = "${aws_key_pair.demo.key_name}"
  ami                         = "${data.aws_ami.server.id}"
  instance_type               = "${var.TYPE}"
  availability_zone           = "${var.REGION}${var.AZ}"
  subnet_id                   = "${aws_subnet.public.id}"
  vpc_security_group_ids      = ["${aws_security_group.default.id}"]
  iam_instance_profile        = "${aws_iam_instance_profile.server.id}"
  associate_public_ip_address = true
}

resource "aws_s3_bucket" "artifacts" {
  bucket = "${replace(random_pet.demo.id,"_","-")}-artifacts"
  acl    = "public-read"
  force_destroy = true
}

output "artifact_bucket_name" {
  value = "${aws_s3_bucket.artifacts.bucket_domain_name}"
}

output "artifact_bucket_id" {
  value = "${aws_s3_bucket.artifacts.id}"
}

output "public_ip_server" {
  value = "${aws_instance.server.public_ip}"
}

output "demo_name" {
  value = "${random_pet.demo.id}"
}


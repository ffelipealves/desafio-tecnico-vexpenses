# Fornecedor AWS
provider "aws" {
  region = "us-east-1"
}

# Variáveis do projeto
variable "projeto" {
  description = "Nome do projeto"
  type        = string
  default     = "VExpenses"
}

variable "candidato" {
  description = "Nome do candidato"
  type        = string
  default     = "SeuNome"
}

# IP específico para acesso via SSH (melhoria de segurança)
variable "meu_ip" {
  description = "IP autorizado para acessar via SSH"
  type        = string
  default     = "192.168.1.1/32" # Substitua pelo seu IP
}

# Gerar chave privada para acesso SSH (sem a necessidade de chave pública preexistente)
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Criar par de chaves para a EC2
resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "${var.projeto}-${var.candidato}-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

# Criar VPC
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.projeto}-${var.candidato}-vpc"
  }
}

# Criar sub-rede na VPC
resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "${var.projeto}-${var.candidato}-subnet"
  }
}

# Criar gateway de internet
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-igw"
  }
}

# Criar tabela de rotas
resource "aws_route_table" "main_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "${var.projeto}-${var.candidato}-route_table"
  }
}

# Associar a tabela de rotas à sub-rede
resource "aws_route_table_association" "main_association" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.main_route_table.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-route_table_association"
  }
}

# Criar Security Group (com melhorias de segurança)
resource "aws_security_group" "main_sg" {
  name        = "${var.projeto}-${var.candidato}-sg"
  description = "Permitir SSH de IP específico e todo o tráfego de saída necessário"
  vpc_id      = aws_vpc.main_vpc.id

  # Regras de entrada (apenas IP específico para SSH)
  ingress {
    description = "Allow SSH from specific IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.meu_ip] # Restringindo a um IP específico
  }

  # Regras de saída (permitindo apenas tráfego necessário)
  egress {
    description = "Allow HTTPS outbound traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow DNS resolution"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow HTTP outbound traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.projeto}-${var.candidato}-sg"
  }
}

# Recuperar a imagem AMI mais recente do Debian 12
data "aws_ami" "debian12" {
  most_recent = true

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["679593333241"]
}

# Criar instância EC2 com a chave SSH e perfil IAM e instalação do Nginx
resource "aws_instance" "debian_ec2" {
  ami                  = data.aws_ami.debian12.id
  instance_type        = "t2.micro"
  subnet_id            = aws_subnet.main_subnet.id
  key_name             = aws_key_pair.ec2_key_pair.key_name
  security_groups      = [aws_security_group.main_sg.name]
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  root_block_device {
    volume_size           = 20
    volume_type           = "gp2"
    encrypted             = true
    delete_on_termination = true
  }

  # Script de inicialização para instalar o Nginx
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get upgrade -y
              apt-get install -y nginx
              systemctl enable nginx
              systemctl start nginx
              EOF

  tags = {
    Name = "${var.projeto}-${var.candidato}-ec2"
  }
}

# Criar o role IAM com política de CloudWatch para a EC2
resource "aws_iam_role" "ec2_role" {
  name = "EC2CloudWatchRole"

  assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }
  EOF
}

# Anexar a política CloudWatch ao role IAM
resource "aws_iam_role_policy_attachment" "cloudwatch_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Criar profile IAM para a instância EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "EC2InstanceProfile"
  role = aws_iam_role.ec2_role.name
}

output "private_key" {
  description = "Chave privada para acessar a instância EC2"
  value       = tls_private_key.ec2_key.private_key_pem
  sensitive   = true
}

output "ec2_public_ip" {
  description = "Endereço IP público da instância EC2"
  value       = aws_instance.debian_ec2.public_ip
}

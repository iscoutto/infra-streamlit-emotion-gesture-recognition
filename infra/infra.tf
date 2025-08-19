# ----------------------------------------
# Recursos da VPC
# ----------------------------------------

# Criação da VPC
resource "aws_vpc" "streamlit_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "VPC"
  }
}

# Criação do Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.streamlit_vpc.id
  tags = {
    Name = "InternetGateway"
  }
}

# ----------------------------------------
# Sub-redes públicas
# ----------------------------------------

# Sub-rede pública A
resource "aws_subnet" "public_subnet_a" {
  vpc_id            = aws_vpc.streamlit_vpc.id
  cidr_block        = var.public_subnet_a_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "PublicSubnetA"
  }
}

# Sub-rede pública B
resource "aws_subnet" "public_subnet_b" {
  vpc_id            = aws_vpc.streamlit_vpc.id
  cidr_block        = var.public_subnet_b_cidr
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "PublicSubnetB"
  }
}

# Tabela de rotas pública
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.streamlit_vpc.id
  tags = {
    Name = "PublicRouteTable"
  }
}

# Rota para o Internet Gateway
resource "aws_route" "public_internet_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associações da tabela de rotas com as sub-redes públicas
resource "aws_route_table_association" "public_a_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_b_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}

# ----------------------------------------
# Sub-redes privadas e NAT Gateways
# ----------------------------------------

# Sub-rede privada A
resource "aws_subnet" "private_subnet_a" {
  vpc_id            = aws_vpc.streamlit_vpc.id
  cidr_block        = var.private_subnet_a_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "PrivateSubnetA"
  }
}

# Sub-rede privada B
resource "aws_subnet" "private_subnet_b" {
  vpc_id            = aws_vpc.streamlit_vpc.id
  cidr_block        = var.private_subnet_b_cidr
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "PrivateSubnetB"
  }
}

# EIP para o NAT Gateway A
resource "aws_eip" "nat_gateway_a_eip" {
  domain = "vpc"
}

# NAT Gateway A
resource "aws_nat_gateway" "nat_gateway_a" {
  allocation_id = aws_eip.nat_gateway_a_eip.id
  subnet_id     = aws_subnet.public_subnet_a.id
}

# EIP para o NAT Gateway B
resource "aws_eip" "nat_gateway_b_eip" {
  domain = "vpc"
}

# NAT Gateway B
resource "aws_nat_gateway" "nat_gateway_b" {
  allocation_id = aws_eip.nat_gateway_b_eip.id
  subnet_id     = aws_subnet.public_subnet_b.id
}

# Tabela de rotas privada A
resource "aws_route_table" "private_rt_a" {
  vpc_id = aws_vpc.streamlit_vpc.id
  tags = {
    Name = "PrivateRouteTableA"
  }
}

# Rota para o NAT Gateway A
resource "aws_route" "private_a_nat_route" {
  route_table_id         = aws_route_table.private_rt_a.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway_a.id
}

# Associação da tabela de rotas com a sub-rede privada A
resource "aws_route_table_association" "private_a_rt_assoc" {
  subnet_id      = aws_subnet.private_subnet_a.id
  route_table_id = aws_route_table.private_rt_a.id
}

# Tabela de rotas privada B
resource "aws_route_table" "private_rt_b" {
  vpc_id = aws_vpc.streamlit_vpc.id
  tags = {
    Name = "PrivateRouteTableB"
  }
}

# Rota para o NAT Gateway B
resource "aws_route" "private_b_nat_route" {
  route_table_id         = aws_route_table.private_rt_b.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway_b.id
}

# Associação da tabela de rotas com a sub-rede privada B
resource "aws_route_table_association" "private_b_rt_assoc" {
  subnet_id      = aws_subnet.private_subnet_b.id
  route_table_id = aws_route_table.private_rt_b.id
}

# ----------------------------------------
# Recursos do ECS
# ----------------------------------------

# Criação do Cluster ECS
resource "aws_ecs_cluster" "streamlit_cluster" {
  name = "StreamlitCluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}


# Desafio tecnico para vaga de estagiario em devops na vexpenses

O desafio consiste no entendimento e elaboração de uma descrição detalhada do arquivo main.tf. Esse arquivo main.tf é um arquivo que define a criação de um estrutura básica na aws

Irei dividir a explicação em blocos de código, onde em cada bloco irei explicar aquela função do código. Após entendermos o código, irei propor as melhorias e modificaçõs no código.

## Tarefa 1

Em um resumo geral esse código Terraform automatiza a criação de uma infraestrutura na AWS, provisionando uma VPC, Subnet, Grupo de Segurança, Par de Chaves SSH e uma Instância EC2. Agora irei detalhar ele passo a passo

### Configuração do provedor AWS
![image](https://github.com/user-attachments/assets/485f2ac1-9e21-4af9-9f3d-41cc02ec82f1)

Aqui vamos definir a AWS como provedor de infraestrutura e logo depois faremos a configuração de onde os recursos serão criados no caso region = "us-east-1"

### Definição de variáveis 
![image](https://github.com/user-attachments/assets/e9a3dcf8-4266-4281-87ea-b1b7a2c39194)

Depois irá ser definido as variaveis para armazenar valores personalizados, que serão usados para nomear os recursos da AWS

### Criação do Par de Chaves

![image](https://github.com/user-attachments/assets/ab4d1f1d-47f9-4bfa-9bd2-6df74a003300)

Uma parte importante de todo processo é a definição da pair key, uma vez que é necessário para acessar a intância EC2 via ssh. Nesse trecho o tls_private_key gera uma chave privada localmente usando o algoritmo RSA com 2048 bits, enquanto o aws_key_pair cria um par de chaves na AWS, utilizando a chave pública gerada. O modelo de criptografia usado é a criptografia assimétrica

A chave é nomeada dinamicamente usando as variáveis projeto e candidato explicadas anteriormente, garantindo nomes únicos para cada usuário.

### Criação da VPC

![image](https://github.com/user-attachments/assets/0661c646-de6a-4baa-8100-fbf7104ce1fc)

Outro elementro importante é a criação da VPC. A VPC cria um ambiente isolado para os recursos da AWS, garantindo segurança e controle sobre a rede.

"cidr_block" define o bloco de IPs da VPC

"enable_dns_support = true" habilita suporte a DNS dentro da VPC 

"enable_dns_hostnames = true" permite que as instâncias EC2 recebam nomes DNS públicos

Apesar da aws criar um vpc padrão ao inicar um EC2, criar uma VPC personalizada nos dá mais controle sobre a infraestrutura de rede

### Criação da Subnet

![image](https://github.com/user-attachments/assets/3f5d4da8-0a44-48da-a8d0-c258ebf58d5d)

Por si só a VPC não define onde os recursos serão implantados. A criação da Subnet vai definir um segmento de rede dentro da VPC, ela permite que instâncias EC2 e outros serviços sejam alocados dentro da VPC, podendo ser uma subnet pública ou privada.

vpc_id = aws_vpc.main_vpc.id essa subnet está dentro da VPC personalizada criada antes

cidr_block = "10.0.1.0/24" define que a subnet terá 256 endereços IPs disponíveis, o bloco CIDR é menor que o da VPC (10.0.0.0/16), pois subnets sempre devem ser subconjuntos da VPC

availability_zone = "us-east-1a" → A subnet será criada na Zona de Disponibilidade us-east-1a. Se quiséssemos alta disponibilidade, poderíamos criar múltiplas subnets em diferentes AZs.

### Configuração do Internet Gateway

![image](https://github.com/user-attachments/assets/094a2736-97c3-40e3-91a4-0c6b938fc5b5)

O Internet Gateway é essencial para permitir o tráfego da internet dentro de uma VPC. Sem um Internet Gateway, as instâncias EC2 não poderão acessar a internet nem serem acessadas externamente.

vpc_id = aws_vpc.main_vpc.id o Internet Gateway será anexado à VPC que criamos antes.


### Configuração do Roteamento

![image](https://github.com/user-attachments/assets/6e92b5d8-c421-4105-8f8b-521b52e38f55)

A tabela de rotas vai definir como o tráfego será encaminhado dentro da VPC

cidr_block = "0.0.0.0/0" vai definir uma rota para todo o tráfego externo

gateway_id = aws_internet_gateway.main_igw.id envia esse tráfego para o Internet Gateway, permitindo acesso à internet.

![image](https://github.com/user-attachments/assets/056203c2-4626-45b0-894c-26f21704913d)

Aqui será associado a subnet a tabela de rotas. Cada subnet precisa estar associada a uma tabela de rotas para definir como o tráfego será encaminhado.

Como associamos a subnet à tabela de rotas que tem uma rota para o IGW, essa subnet agora é pública. Isso significa que qualquer instância EC2 lançada nessa subnet terá acesso à internet

### Configuração do Grupo de Segurança para controle de acessos

![image](https://github.com/user-attachments/assets/1bcdc555-8625-4033-a76b-fa23b46147f6)

Aqui criamos um Security Group (SG) dentro da VPC, que vai definir quais conexões são permitidas para a instância EC2.

No trecho Ingress temos as regras de entrada:

from_port = 22 e to_port = 22 - permite conexões na porta 22 (SSH).

protocol = "tcp" - define o protocolo TCP.

cidr_blocks = ["0.0.0.0/0"] -  Permite SSH de qualquer IP, o que pode ser um risco de segurança.

ipv6_cidr_blocks = ["::/0"] - Permite SSH de qualquer endereço IPv6

Agora para regras de saida Egress, temos:

from_port = 0 e to_port = 0 -Permite qualquer conexão de saída

protocol = "-1" - Indica que todos os protocolos são permitidos.

cidr_blocks = ["0.0.0.0/0"] - Permite tráfego para qualquer destino

Com essas configurações garantimos que conseguimos acessar a instância via SSH, e também permite que a instância faça requisições para a internet

### Escolha da AMI

![image](https://github.com/user-attachments/assets/527f07be-d345-4739-a229-819bc438009c)

A escolha da AMI (Amazon Machine Image), define qual sistema operacional será instalado na instância EC2. Vale ressaltar em vez de definir um ID fixo de AMI, estamos buscando dinamicamente a AMI mais recente do Debian, isso torna o Terraform mais reutilizável, uma vez que nao ficará fixo e desatualizado em uma só versão.

### Criação da instância EC2

![image](https://github.com/user-attachments/assets/eba5b4a8-8e31-43bb-b721-9fbdae4da393)

Este código cria uma instância EC2 usando a AMI mais recente do Debian 12. Entendo cada trecho:

ami = data.aws_ami.debian12.id - Define qual sistema operacional será instalado na instância no caso Debian 12

instance_type = "t2.micro" - Define o hardware da máquina (t2.micro possui 1 vCPU, 1GB RAM)

subnet_id = aws_subnet.main_subnet.id - Especifica em qual sub-rede a instância será criada.

key_name = aws_key_pair.ec2_key_pair.key_name - Permite acessar a instância via SSH

security_groups = [...] - Define regras de firewall para a instância. Usa o grupo de segurança que já configuramos (main_sg)

associate_public_ip_address = true - Garante que a instância receba um IP público, permitindo o acesso via SSH.

root_block_device - Define o disco principal da máquina.

### Output

![image](https://github.com/user-attachments/assets/571f9ae2-3209-4314-a889-f445767ca233)

Os outputs servem para exibir informações úteis no terminal após a execução do Terraform.

private_key vai exibir a chave privada gerada no início do código. ec2_public_ip vai mostrar o endereço IP público da instância EC2, também permite acessar a máquina via SSH depois que ela for criada.

## Tarefa 2

### Melhorias de segurança que podem ser aplicadas
Todas modificações estão contidas e comentadas no aquivo main.tf desse repositório

#### Restringir Acesso SSH
Em vez de permitir SSH de qualquer lugar (0.0.0.0/0), podemos retringir o acesso a um IP específico (exemplo: meu_ip).

#### Criar um Papel IAM para a EC2
A EC2 não tinha permissões IAM para enviar logs ao CloudWatch. Em vez de rodar comandos diretamente na EC2 com permissões irrestritas, criei um papel IAM e o associei à instância.

#### Habilitar Logs e Monitoramento com CloudWatch
Adiciei permissões para que a EC2 envie logs ao AWS CloudWatch.

#### Habilitar o Encrypted EBS (Disco da EC2)
Podemos configurar disco raiz da EC2 para usar criptografia dando uma camada extra de segurança para nossos dados.

#### Melhorar as Regras de Segurança
Criamos regras de saída mais seguras no Security Group, permitindo apenas tráfego necessário.

#### Automatização Nginx

Para automatizar a instalação e inicialização do Nginx na sua instância EC2, podemos usar o recurso user_data no Terraform, que permite executar comandos de inicialização no momento da criação da instância.

#### Resumo do resultado esperado

Estas alterações configuram a infraestrutura da AWS utilizando o Terraform para fornecer um conjunto de recursos essenciais, incluindo uma instância EC2 com um sistema Debian 12, monitoramento via CloudWatch, e a instalação do Nginx. A seguir está uma descrição dos resultados esperados:

##### Infraestrutura Provisionada:
Uma VPC com uma sub-rede configurada.

Gateway de internet configurado para a VPC.

Instância EC2 Debian 12 criada, com Nginx instalado e CloudWatch Agent configurado.

A instância EC2 estará acessível via SSH apenas a partir do IP especificado na variável meu_ip.

##### Monitoramento:

O agente CloudWatch será executado na instância EC2, permitindo a coleta de métricas e logs de desempenho.

##### Segurança:

A instância EC2 estará protegida pelo Security Group que restringe o tráfego SSH a um IP específico e permite tráfego necessário (HTTP, HTTPS e DNS).

##### Facilidade de Acesso:

O Nginx será instalado e executado, e a instância EC2 poderá ser acessada por seu IP público para visualização da página padrão do Nginx.








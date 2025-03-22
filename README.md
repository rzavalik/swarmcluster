# Docker Swarm + AWS + Terraform + .NET

Exemplo simples de um aplicativo composto de dois containers.
JokePresentation é uma interface em .NET Core 9 (Web) que consome uma Minimum API (JokeProvider).
JokeProvider é uma API baseada em .NET Core 9 que obtém, através de um arquivo JSON, uma piada aleatória.
Ambos aplicativos estão publicados através de um Cluster baseado em Docker Swarm.

JokePresentation consome JokeProvider através de uma overlay network, que permite balancear a carga entre os Workers.
JokePresentation é exposto através de um Application Load Balancer, que balanceia a carga do mundo externo entre os Workers.

Foi utilizado um Script baseado em Terraform para criar a VPC, Subnets, instâncias EC2 e Security Groups.
Depois de montado o Cluster, basta inicializar através do comando docker-compose. Para facilitar, foi criado um arquivo start.sh que já possui os comandos de inicialização.

[http://swarmcluster-joke-lb-539831266.us-east-1.elb.amazonaws.com/]

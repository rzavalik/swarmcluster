# ECR Login
sudo aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 588738580149.dkr.ecr.us-east-1.amazonaws.com

# Stack Deploy
sudo docker stack deploy -c docker-compose.yml jokestack --prune
sudo docker service update jokestack_jokepresentation
sudo docker service update jokestack_jokeprovider

# Stack Status
sudo docker stack services jokestack
sudo docker stack ps jokestack
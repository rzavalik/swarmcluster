sudo aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 588738580149.dkr.ecr.us-east-1.amazonaws.com
sudo docker stack deploy -c docker-compose.yml jokestack
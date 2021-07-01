docker tag cedelis/mailman:0.5 ${AWS_ACCOUNT}.dkr.ecr.us-east-2.amazonaws.com/mailman:0.5
docker push ${AWS_ACCOUNT}.dkr.ecr.us-east-2.amazonaws.com/mailman:0.5

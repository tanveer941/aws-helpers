# Fargate CloudFormation and Terraform templates

## Task mode
Containers are spawned on the occurence of an event.  

## Service(Networking) mode
The task definitions for Fargate require that the network mode is set to awsvpc. This provides each task with its 
own elastic network interface. Ideal for hosting API's and interacting with other services. Once the 
container is down its ENI is also deleted, one cannot delete it manually.
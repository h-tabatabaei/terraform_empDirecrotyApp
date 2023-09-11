# terraform_empDirecrotyApp
Terraform Infrastructure code to deply Employee Directory Application on AWS Cloud environment.

The project I undertook centered around the laboratory exercises within the 'AWS Cloud Technical Essentials' course available on Coursera. Throughout this course, our instructors navigated the AWS Management Console to demonstrate various cloud computing concepts and practical implementations. 

What set my approach apart was the transformation of each of these exercises into Terraform scripts. With Terraform, I could encapsulate the infrastructure configurations, making them reproducible and easily manageable. This allowed me to apply or destroy the cloud resources efficiently, aligning with the pace of the course.

In essence, my adaptation to Terraform scripting not only mirrored the practical exercises but also provided a valuable learning experience in infrastructure as code (IaC), a fundamental concept in modern cloud computing. It showcased the power of automating resource provisioning and management, contributing to a deeper understanding of AWS and cloud technology as a whole.

To use the code do as following steps:

1) create AWS User authentication environment variables.
	AWS_ACCESS_KEY_ID
	AWS_SECRET_ACCESS_KEY

2) Navigate to the path containing tf files.

3) run the initiate command to get essential providers and modules.
	terraform init

4) verify the validation of the code.
	terraform validate

5) deploy the infrastructure.
	terraform deploy -auto-approve

6) to destroy the infrastructure:
	terrafrom destroy -auto-approve




# Automation
Automation with Terraform, Ansible and GitHub Action

1. You don't need to create S3 bucket, The Python SDK in Terraform/prod/Network/create_s3_bucket.py will create it automatically
2. Run the code in the GitHub Action. Don't forget to Update GitGub repository environments.
3. Public Key exists in the Trraform/prod/Webserver folder. 
4. Private Key exists in GitHub repository environment with the name: ANSIBLE_PRIVATE_KEY 
5. If you want to run code manually, you can create python venv, and install Terraform/prod/Network/myven_pip_requirments.txt, then run creae_s3_bucket.py to create S3 bucket.
6. If you don't want to create S3 bucekt through Python SDK, you can connect through AWS Cli, then run this code: aws s3api create-bucket --bucket prod-behzad-bucket
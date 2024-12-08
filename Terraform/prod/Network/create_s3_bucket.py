# This is SDK for aws
import boto3
from botocore.exceptions import ClientError

def create_s3_bucket(bucket_name, region="us-east-1"):
    s3 = boto3.client('s3', region_name=region)
    
    try:
        # For region us-east-1, we don't need to specify LocationConstraint
        if region == 'us-east-1':
            s3.create_bucket(Bucket=bucket_name)
        else:
            s3.create_bucket(Bucket=bucket_name, CreateBucketConfiguration={'LocationConstraint': region})
        print(f"Bucket {bucket_name} created successfully in {region}.")
    except ClientError as e:
        print(f"Error creating bucket: {e}")

if __name__ == "__main__":
    bucket_name = "prod-behzad-bucket"
    create_s3_bucket(bucket_name)

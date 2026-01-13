import boto3
import sys

def bootstrap_customer(customer_name, region="eu-central-1"):
    s3 = boto3.client('s3', region_name=region)
    dynamodb = boto3.client('dynamodb', region_name=region)
    
    bucket_name = f"{customer_name}-terraform-state"
    table_name = "terraform-state-lock"

    # 1. Create S3 Bucket
    try:
        print(f"Creating bucket: {bucket_name}...")
        s3.create_bucket(Bucket=bucket_name, CreateBucketConfiguration={'LocationConstraint': region})
        s3.put_bucket_versioning(Bucket=bucket_name, VersioningConfiguration={'Status': 'Enabled'})
        print(f"✅ S3 Bucket created with Versioning.")
    except Exception as e:
        print(f"❌ S3 Error: {e}")

    # 2. Create DynamoDB Table for Locking
    try:
        print(f"Creating DynamoDB table: {table_name}...")
        dynamodb.create_table(
            TableName=table_name,
            KeySchema=[{'AttributeName': 'LockID', 'KeyType': 'HASH'}],
            AttributeDefinitions=[{'AttributeName': 'LockID', 'AttributeType': 'S'}],
            ProvisionedThroughput={'ReadCapacityUnits': 5, 'WriteCapacityUnits': 5}
        )
        print(f"✅ DynamoDB Table created.")
    except dynamodb.exceptions.ResourceInUseException:
        print(f"ℹ️ DynamoDB Table already exists, skipping.")
    except Exception as e:
        print(f"❌ DynamoDB Error: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 bootstrap_customer.py <customer-name>")
    else:
        bootstrap_customer(sys.argv[1])
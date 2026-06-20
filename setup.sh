#!/bin/bash

# 1. Criar a tabela no DynamoDB
echo "Criando a tabela no Amazon DynamoDB..."
aws dyanmodb create-table \
    --table-name DadosArquivos \
    --attribute-definitions AttributeName=id,AttributeType=S \
    --key-schema AttributeName=id,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5

# 2. Criar a Role do IAM para a Lambda ter permissão de execução e acesso ao DynamoDB
echo "Criando a IAM Role para a Lambda..."
cat <<EOF > trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "lambda.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

ROLE_ARN=$(aws iam create-role --role-name LambdaDynamoS3Role --assume-role-policy-document file://trust-policy.json --query 'Role.Arn' --output text)

# Anexa permissões básicas de logs e acesso total ao DynamoDB para simplificar o lab
aws iam attach-role-policy --role-name LambdaDynamoS3Role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam attach-role-policy --role-name LambdaDynamoS3Role --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess

echo "Aguardando 10 segundos para a Role propagar na AWS..."
sleep 10

# 3. Criar a Função Lambda
echo "Criando a Função AWS Lambda..."
LAMBDA_ARN=$(aws lambda create-function \
    --function-name processa-s3-real \
    --runtime nodejs18.x \
    --zip-file fileb://lambda.zip \
    --handler index.handler \
    --role $ROLE_ARN \
    --query 'FunctionArn' --output text)

# 4. Criar o Bucket no S3 (Dica: substitua 'meu-bucket-arquivos-original-xyz' por um nome único, pois o S3 é global)
BUCKET_NAME="meu-bucket-arquivos-original-xyz"
echo "Criando o Bucket S3: $BUCKET_NAME..."
aws s3 mb s3://$BUCKET_NAME

# Dar permissão para o S3 invocar a Lambda
aws lambda add-permission \
    --function-name processa-s3-real \
    --statement-id s3-invoke-permission \
    --action lambda:InvokeFunction \
    --principal s3.amazonaws.com \
    --source-arn arn:aws:s3:::$BUCKET_NAME

# 5. Configurar o Trigger (Gatilho) no S3
echo "Vinculando o Trigger do S3 para a Lambda..."
cat <<EOF > notification.json
{
  "LambdaFunctionConfigurations": [
    {
      "LambdaFunctionArn": "$LAMBDA_ARN",
      "Events": ["s3:ObjectCreated:*"]
    }
  ]
}
EOF

aws s3api put-bucket-notification-configuration \
    --bucket $BUCKET_NAME \
    --notification-configuration file://notification.json

echo "Parabéns! Toda a infraestrutura da imagem foi automatizada com sucesso na AWS real!"

const { DynamoDBClient, PutItemCommand } = require("@aws-sdk/client-dynamodb");

// Na AWS real, ele detecta a região automaticamente
const dynamoClient = new DynamoDBClient({});

exports.handler = async (event) => {
    const bucket = event.Records[0].s3.bucket.name;
    const key = event.Records[0].s3.object.key;

    console.log(`Arquivo detectado no S3: ${key} do bucket ${bucket}`);

    const params = {
        TableName: "DadosArquivos",
        Item: {
            "id": { S: key },
            "bucket": { S: bucket },
            "timestamp": { S: new Date().toISOString() }
        }
    };

    try {
        await dynamoClient.send(new PutItemCommand(params));
        console.log("Dados gravados no DynamoDB com sucesso!");
        return { statusCode: 200, body: "Sucesso" };
    } catch (err) {
        console.error("Erro ao gravar no DynamoDB:", err);
        throw err;
    }
};

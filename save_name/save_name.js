const AWS = require('aws-sdk');
const docClient = new AWS.DynamoDB.DocumentClient();

module.exports.handler = async (event) => {
    const params = {
        TableName : process.env.TABLE_NAME,
        Item: {
            ID: '1',
            name: JSON.parse(event.body).name
        }
    };

    try {
        await docClient.put(params).promise();
        return {
            statusCode: 200,
            body: JSON.stringify('Name saved'),
        };
    } catch (err) {
        console.log(err);
        return {
            statusCode: 500,
            body: JSON.stringify('Error saving name'),
        };
    }
};
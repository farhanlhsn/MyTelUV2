const { S3Client } = require('@aws-sdk/client-s3');

const r2Client = new S3Client({
    region: "auto",
    endpoint : process.env.R2_URL ,
    credentials: {
        accessKeyId: process.env.R2_ACCESSKEY,
        secretAccessKey: process.env.R2_SECRETACCESSKEY,
    },
});

module.exports = r2Client;
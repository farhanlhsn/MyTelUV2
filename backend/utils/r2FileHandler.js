const r2Client = require('../config/r2Config');
const { PutObjectCommand, DeleteObjectCommand, HeadObjectCommand } = require("@aws-sdk/client-s3");
const path = require('path');
const { v4: uuidv4 } = require('uuid');

const BUCKET_NAME = process.env.R2_BUCKET_NAME;

const uploadFile = async (fileBuffer, fileName, mimeType, folder) => {
    try {
        // Generate unique file name
        const fileExtension = path.extname(fileName);
        const uniqueFileName = `${uuidv4()}${fileExtension}`;
        const fileKey = `${folder}/${uniqueFileName}`;

        const uploadParams = {
            Bucket: BUCKET_NAME,
            Key: fileKey,
            Body: fileBuffer,
            ContentType: mimeType,
            // Make file publicly readable
            ACL: 'public-read',
            // Set cache control
            CacheControl: 'max-age=31536000', // 1 year
            // Add metadata
            Metadata: {
                'original-name': fileName,
                'upload-date': new Date().toISOString(),
                'folder': folder
            }
        };

        const command = new PutObjectCommand(uploadParams);
        await r2Client.send(command);

        // Construct the public URL
        let publicUrl = process.env.R2_PUBLIC_URL;
        
        // Ensure URL has protocol
        if (publicUrl && !publicUrl.startsWith('http://') && !publicUrl.startsWith('https://')) {
            publicUrl = `https://${publicUrl}`;
        }
        
        const fileUrl = `${publicUrl}/${fileKey}`;

        return {
            success: true,
            fileUrl,
            fileKey,
            fileName: uniqueFileName,
            originalName: fileName,
            folder,
            size: fileBuffer.length,
            mimeType
        };
    } catch (error) {
        console.error('Error uploading file to R2:', error);
        throw new Error(`Failed to upload file: ${error.message}`);
    }
};


const deleteFile = async (fileKey) => {
    try {
        const deleteParams = {
            Bucket: BUCKET_NAME,
            Key: fileKey
        };

        const command = new DeleteObjectCommand(deleteParams);
        await r2Client.send(command);

        return {
            success: true,
            message: 'File deleted successfully',
            fileKey
        };
    } catch (error) {
        console.error('Error deleting file from R2:', error);
        throw new Error(`Failed to delete file: ${error.message}`);
    }
};

const fileExists = async (fileKey) => {
    try {
        const headParams = {
            Bucket: BUCKET_NAME,
            Key: fileKey
        };

        const command = new HeadObjectCommand(headParams);
        await r2Client.send(command);
        return true;
    } catch (error) {
        if (error.name === 'NotFound' || error.name === 'NoSuchKey') {
            return false;
        }
        throw error;
    }
};

module.exports = {
    uploadFile,
    deleteFile,
    fileExists
};
const r2Client = require('../config/r2Config');
const { PutObjectCommand, DeleteObjectCommand, HeadObjectCommand } = require("@aws-sdk/client-s3");
const path = require('path');
const { v4: uuidv4 } = require('uuid');

const BUCKET_NAME = process.env.R2_BUCKET_NAME;

const getConfiguredAcl = (options = {}) => {
    const acl = options.acl || process.env.R2_OBJECT_ACL;
    if (!acl || acl.toLowerCase() === 'private') {
        return undefined;
    }
    return acl;
};

const uploadFile = async (fileBuffer, fileName, mimeType, folder, options = {}) => {
    // Mock upload for tests
    if (process.env.TEST_MODE === 'true') {
        return {
            success: true,
            fileUrl: `https://mock-r2.com/${folder}/${fileName}`,
            fileKey: `${folder}/${fileName}`,
            fileName: fileName,
            originalName: fileName,
            folder,
            size: fileBuffer.length,
            mimeType
        };
    }

    try {
        // Generate unique file name
        const fileExtension = path.extname(fileName);
        const uniqueFileName = `${uuidv4()}${fileExtension}`;
        const fileKey = `${folder}/${uniqueFileName}`;
        const configuredAcl = getConfiguredAcl(options);

        const uploadParams = {
            Bucket: BUCKET_NAME,
            Key: fileKey,
            Body: fileBuffer,
            ContentType: mimeType,
            // Set cache control
            CacheControl: options.cacheControl || 'max-age=31536000', // 1 year
            // Add metadata
            Metadata: {
                'original-name': fileName,
                'upload-date': new Date().toISOString(),
                'folder': folder
            }
        };

        if (configuredAcl) {
            uploadParams.ACL = configuredAcl;
        }

        const command = new PutObjectCommand(uploadParams);
        await r2Client.send(command);

        // Construct the public URL
        let publicUrl = process.env.R2_PUBLIC_URL;
        
        // Ensure URL has protocol
        if (publicUrl && !publicUrl.startsWith('http://') && !publicUrl.startsWith('https://')) {
            publicUrl = `https://${publicUrl}`;
        }

        // Existing call sites persist `fileUrl` in DB fields that expect strings.
        // For private buckets without a public base URL, store the object key so
        // the file can later be served through an authenticated/signed-url route.
        const fileUrl = publicUrl ? `${publicUrl.replace(/\/$/, '')}/${fileKey}` : fileKey;

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
    // Mock delete for tests
    if (process.env.TEST_MODE === 'true') {
        return { success: true, message: 'File deleted successfully (mock)', fileKey };
    }

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
    // Mock fileExists for tests
    if (process.env.TEST_MODE === 'true') {
        return true;
    }

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

const swaggerJSDoc = require('swagger-jsdoc');

const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'MyTelUV2 API Documentation',
      version: '1.0.0',
      description: 'API documentation for MyTelUV2 Backend Services',
    },
    servers: [
      {
        url: 'http://localhost:5050/api/v1',
        description: 'Development server',
      },
      {
        url: process.env.FRONTEND_URL ? process.env.FRONTEND_URL.replace(/:\d+$/, ':5050/api/v1') : 'http://213.210.37.132:5050/api/v1',
        description: 'Production server',
      },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
    },
    security: [
      {
        bearerAuth: [],
      },
    ],
  },
  apis: ['./routes/*.js', './controllers/*.js'], // Path to the API docs
};

const swaggerSpec = swaggerJSDoc(options);

module.exports = swaggerSpec;

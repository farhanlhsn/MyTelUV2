const { PrismaClient } = require('../generated/prisma');

// Create a single PrismaClient instance and export it
// This avoids creating multiple connections in development
let prisma;

if (process.env.NODE_ENV === 'production') {
    prisma = new PrismaClient({
        log: [
          { level: 'warn', emit: 'event' },
          { level: 'error', emit: 'event' },
          { level: 'query', emit: 'event' },
        ],
      });
} else {
    if (!global.__prisma) {
        global.__prisma = new PrismaClient({
            log: [
              { level: 'error', emit: 'event' },
            ],
          });
    }
    prisma = global.__prisma;
}

// Logging untuk query Prisma
prisma.$on('query', (e) => {
    console.log(`Query: ${e.query}`);
    console.log(`Params: ${e.params}`);
    console.log(`Duration: ${e.duration}ms`);
  });
  
  prisma.$on('warn', (e) => {
    console.warn(`Prisma Warning: ${e.message}`);
  });
  
  prisma.$on('error', (e) => {
    console.error(`Prisma Error: ${e.message}`);
  });
  

module.exports = prisma;



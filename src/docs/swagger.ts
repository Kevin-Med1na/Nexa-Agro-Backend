import swaggerJsdoc from "swagger-jsdoc";

const options = {
  definition: {
    openapi: "3.0.0",
    info: {
      title: "Nexa Agro API",
      version: "1.0.0",
      description:
        "REST API para la plataforma Nexa Agro. Conecta productores, empresas y transportistas del sector agrícola.",
      contact: {
        name: "Equipo Nexa",
      },
    },
    servers: [
      {
        url: "http://localhost:3000",
        description: "Servidor local",
      },
      {
        url: "https://nexa-agro-backend.onrender.com",
        description: "Servidor producción",
      },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: "http",
          scheme: "bearer",
          bearerFormat: "JWT",
        },
      },
    },
  },
  apis: ["./src/routes/*.ts"],
};

export default swaggerJsdoc(options);
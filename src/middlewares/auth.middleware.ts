import { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";

const JWT_SECRET = process.env.JWT_SECRET || "nexa_agro_secret";

// Extender el tipo Request para incluir el usuario autenticado
export interface AuthRequest extends Request {
  usuario?: {
    id: number;
    email: string;
    rol: string;
  };
}

/**
 * Middleware que verifica el JWT en el header Authorization.
 * Si es válido, inyecta los datos del usuario en req.usuario.
 */
export const verificarToken = (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): void => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    res.status(401).json({ mensaje: "Token no proporcionado" });
    return;
  }

  const token = authHeader.split(" ")[1];

  try {
    const decoded = jwt.verify(token, JWT_SECRET) as {
      id: number;
      email: string;
      rol: string;
    };
    req.usuario = decoded;
    next();
  } catch {
    res.status(401).json({ mensaje: "Token inválido o expirado" });
  }
};

/**
 * Middleware de autorización por rol.
 * Uso: verificarRol('productor', 'empresa')
 */
export const verificarRol = (...rolesPermitidos: string[]) => {
  return (req: AuthRequest, res: Response, next: NextFunction): void => {
    if (!req.usuario) {
      res.status(401).json({ mensaje: "No autenticado" });
      return;
    }

    if (!rolesPermitidos.includes(req.usuario.rol)) {
      res.status(403).json({
        mensaje: `Acceso denegado. Se requiere uno de estos roles: ${rolesPermitidos.join(", ")}`,
      });
      return;
    }

    next();
  };
};
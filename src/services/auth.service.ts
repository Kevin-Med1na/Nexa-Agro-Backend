import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import prisma from "../models/prisma.client";

const JWT_SECRET = process.env.JWT_SECRET || "nexa_agro_secret";
const JWT_EXPIRES_IN = "7d";

// ── Tipos ──────────────────────────────────────────────────
interface RegisterInput {
  nombre: string;
  email: string;
  contrasena: string;
  telefono?: string;
  direccion?: string;
  tipo_usuario: string; // 'productor' | 'empresa' | 'transportista'
}

interface LoginInput {
  email: string;
  contrasena: string;
}

// ── Helpers ────────────────────────────────────────────────
const generarToken = (payload: object): string => {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
};

// ── Servicios ──────────────────────────────────────────────

/**
 * Registra un nuevo usuario.
 * Busca el tipo_usuario por nombre, hashea la contraseña,
 * y asigna el plan básico por defecto.
 */
export const registrarUsuario = async (data: RegisterInput) => {
  // 1. Verificar que el email no exista
  const existe = await prisma.usuario.findUnique({
    where: { email: data.email },
  });
  if (existe) throw new Error("El email ya está registrado");

  // 2. Obtener el tipo de usuario por nombre
  const tipoUsuario = await prisma.tipo_usuario.findUnique({
    where: { nombre: data.tipo_usuario },
  });
  if (!tipoUsuario) throw new Error("Tipo de usuario inválido");

  // 3. Obtener el plan básico (asignado por defecto al registrarse)
  const planBasico = await prisma.suscripcion.findUnique({
    where: { nombre: "basico" },
  });
  if (!planBasico) throw new Error("Plan básico no encontrado");

  // 4. Hashear contraseña
  const hash = await bcrypt.hash(data.contrasena, 10);

  // 5. Crear usuario
  const usuario = await prisma.usuario.create({
    data: {
      nombre: data.nombre,
      email: data.email,
      contrasena: hash,
      telefono: data.telefono,
      direccion: data.direccion,
      id_tipo_usuario: tipoUsuario.id_tipo_usuario,
      id_suscripcion: planBasico.id_suscripcion,
      suscripcion_activa: true,
    },
    select: {
      id_usuario: true,
      nombre: true,
      email: true,
      estado: true,
      suscripcion_activa: true,
      tipo_usuario: { select: { nombre: true } },
      suscripcion: { select: { nombre: true, alcance: true } },
    },
  });

  // 6. Generar token
  const token = generarToken({
    id: usuario.id_usuario,
    email: usuario.email,
    rol: usuario.tipo_usuario.nombre,
  });

  return { usuario, token };
};

/**
 * Inicia sesión con email y contraseña.
 * Devuelve el usuario y un JWT.
 */
export const loginUsuario = async (data: LoginInput) => {
  // 1. Buscar usuario
  const usuario = await prisma.usuario.findUnique({
    where: { email: data.email },
    include: {
      tipo_usuario: { select: { nombre: true } },
      suscripcion: { select: { nombre: true, alcance: true } },
    },
  });
  if (!usuario) throw new Error("Credenciales inválidas");

  // 2. Verificar estado
  if (usuario.estado !== "activo") {
    throw new Error("Tu cuenta está suspendida o inactiva");
  }

  // 3. Comparar contraseña
  const valida = await bcrypt.compare(data.contrasena, usuario.contrasena);
  if (!valida) throw new Error("Credenciales inválidas");

  // 4. Generar token
  const token = generarToken({
    id: usuario.id_usuario,
    email: usuario.email,
    rol: usuario.tipo_usuario.nombre,
  });

  // 5. Retornar sin la contraseña
  const { contrasena: _, ...usuarioSinPassword } = usuario;
  return { usuario: usuarioSinPassword, token };
};

/**
 * Devuelve el perfil del usuario autenticado.
 */
export const obtenerPerfil = async (id_usuario: number) => {
  const usuario = await prisma.usuario.findUnique({
    where: { id_usuario },
    select: {
      id_usuario: true,
      nombre: true,
      email: true,
      telefono: true,
      direccion: true,
      fecha_registro: true,
      estado: true,
      suscripcion_activa: true,
      tipo_usuario: { select: { nombre: true, descripcion: true } },
      suscripcion: {
        select: {
          nombre: true,
          alcance: true,
          mensualidad: true,
          incluye_publicidad: true,
          incluye_filtros: true,
          incluye_oferta_demanda: true,
        },
      },
      ubicacion: true,
    },
  });
  if (!usuario) throw new Error("Usuario no encontrado");
  return usuario;
};
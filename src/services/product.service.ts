import prisma from "../models/prisma.client";
import { Prisma } from "../../dist/generated/prisma";

export interface ProductFilters {
  tipo?: string;
  minPrecio?: number;
  maxPrecio?: number;
  disponible?: boolean;
  search?: string;
  id_usuario?: number;
}

export interface CreateProductInput {
  id_usuario: number;
  nombre: string;
  tipo: string;
  precio: number;
  descripcion?: string;
  unidad_medida?: string;
  stock?: number;
  id_ubicacion?: number;
}

export interface UpdateProductInput {
  nombre?: string;
  tipo?: string;
  precio?: number;
  descripcion?: string;
  unidad_medida?: string;
  stock?: number;
  disponible?: boolean;
  id_ubicacion?: number;
}

export const createProduct = async (data: CreateProductInput) => {
  return await prisma.producto.create({
    data: {
      ...data,
      precio: new Prisma.Decimal(data.precio),
    },
    include: {
      usuario: {
        select: {
          nombre: true,
          email: true
        }
      },
      ubicacion: true
    }
  });
};

export const getProducts = async (filters: ProductFilters) => {
  const where: any = {};

  if (filters.tipo) {
    where.tipo = filters.tipo;
  }

  if (filters.disponible !== undefined) {
    where.disponible = filters.disponible;
  }

  if (filters.id_usuario) {
    where.id_usuario = filters.id_usuario;
  }

  if (filters.minPrecio !== undefined || filters.maxPrecio !== undefined) {
    where.precio = {};
    if (filters.minPrecio !== undefined) where.precio.gte = new Prisma.Decimal(filters.minPrecio);
    if (filters.maxPrecio !== undefined) where.precio.lte = new Prisma.Decimal(filters.maxPrecio);
  }

  if (filters.search) {
    where.OR = [
      { nombre: { contains: filters.search, mode: 'insensitive' } },
      { descripcion: { contains: filters.search, mode: 'insensitive' } },
    ];
  }

  return await prisma.producto.findMany({
    where,
    include: {
      usuario: {
        select: {
          nombre: true,
        }
      },
      ubicacion: true
    },
    orderBy: {
      fecha_publicacion: 'desc'
    }
  });
};

export const getProductById = async (id: number) => {
  const producto = await prisma.producto.findUnique({
    where: { id_producto: id },
    include: {
      usuario: {
        select: {
          id_usuario: true,
          nombre: true,
          email: true,
          telefono: true
        }
      },
      ubicacion: true,
      publicidad_producto: true
    }
  });

  if (!producto) {
    throw new Error("Producto no encontrado");
  }

  return producto;
};

export const updateProduct = async (id: number, data: UpdateProductInput) => {
  // Verificar si existe
  await getProductById(id);

  const updateData: any = { ...data };
  if (data.precio !== undefined) {
    updateData.precio = new Prisma.Decimal(data.precio);
  }

  return await prisma.producto.update({
    where: { id_producto: id },
    data: updateData,
    include: {
      ubicacion: true
    }
  });
};

export const deleteProduct = async (id: number) => {
  // Verificar si existe
  await getProductById(id);

  return await prisma.producto.delete({
    where: { id_producto: id }
  });
};

import { Request, Response } from "express";
import * as productService from "../services/product.service";
import { AuthRequest } from "../middlewares/auth.middleware";

export const createProduct = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { nombre, tipo, precio, descripcion, unidad_medida, stock, id_ubicacion } = req.body;

    if (!nombre || !tipo || precio === undefined) {
      res.status(400).json({ mensaje: "Faltan campos obligatorios: nombre, tipo, precio" });
      return;
    }

    if (!req.usuario) {
      res.status(401).json({ mensaje: "Usuario no autenticado" });
      return;
    }

    const producto = await productService.createProduct({
      id_usuario: req.usuario.id,
      nombre,
      tipo,
      precio: Number(precio),
      descripcion,
      unidad_medida,
      stock: stock ? Number(stock) : 0,
      id_ubicacion: id_ubicacion ? Number(id_ubicacion) : undefined
    });

    res.status(201).json({
      mensaje: "Producto creado exitosamente",
      producto
    });
  } catch (error: any) {
    res.status(500).json({ mensaje: "Error al crear producto", detalle: error.message });
  }
};

export const getProducts = async (req: Request, res: Response): Promise<void> => {
  try {
    const { tipo, minPrecio, maxPrecio, disponible, search, id_usuario } = req.query;

    const filters: productService.ProductFilters = {
      tipo: tipo as string,
      minPrecio: minPrecio ? Number(minPrecio) : undefined,
      maxPrecio: maxPrecio ? Number(maxPrecio) : undefined,
      disponible: disponible === 'true' ? true : disponible === 'false' ? false : undefined,
      search: search as string,
      id_usuario: id_usuario ? Number(id_usuario) : undefined
    };

    const productos = await productService.getProducts(filters);

    res.status(200).json({ productos });
  } catch (error: any) {
    res.status(500).json({ mensaje: "Error al obtener productos", detalle: error.message });
  }
};

export const getProductById = async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const producto = await productService.getProductById(Number(id));

    res.status(200).json({ producto });
  } catch (error: any) {
    if (error.message === "Producto no encontrado") {
      res.status(404).json({ mensaje: error.message });
      return;
    }
    res.status(500).json({ mensaje: "Error al obtener el producto", detalle: error.message });
  }
};

export const updateProduct = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const { nombre, tipo, precio, descripcion, unidad_medida, stock, disponible, id_ubicacion } = req.body;

    if (!req.usuario) {
      res.status(401).json({ mensaje: "Usuario no autenticado" });
      return;
    }

    const productoActual = await productService.getProductById(Number(id));
    if (productoActual.id_usuario !== req.usuario.id) {
      res.status(403).json({ mensaje: "No tienes permiso para editar este producto" });
      return;
    }

    const producto = await productService.updateProduct(Number(id), {
      nombre,
      tipo,
      precio: precio !== undefined ? Number(precio) : undefined,
      descripcion,
      unidad_medida,
      stock: stock !== undefined ? Number(stock) : undefined,
      disponible: disponible !== undefined ? Boolean(disponible) : undefined,
      id_ubicacion: id_ubicacion !== undefined ? Number(id_ubicacion) : undefined
    });

    res.status(200).json({
      mensaje: "Producto actualizado exitosamente",
      producto
    });
  } catch (error: any) {
    if (error.message === "Producto no encontrado") {
      res.status(404).json({ mensaje: error.message });
      return;
    }
    res.status(500).json({ mensaje: "Error al actualizar el producto", detalle: error.message });
  }
};

export const deleteProduct = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    if (!req.usuario) {
      res.status(401).json({ mensaje: "Usuario no autenticado" });
      return;
    }

    const productoActual = await productService.getProductById(Number(id));
    if (productoActual.id_usuario !== req.usuario.id) {
      res.status(403).json({ mensaje: "No tienes permiso para eliminar este producto" });
      return;
    }

    await productService.deleteProduct(Number(id));

    res.status(200).json({ mensaje: "Producto eliminado exitosamente" });
  } catch (error: any) {
    if (error.message === "Producto no encontrado") {
      res.status(404).json({ mensaje: error.message });
      return;
    }
    res.status(500).json({ mensaje: "Error al eliminar el producto", detalle: error.message });
  }
};

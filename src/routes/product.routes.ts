import { Router } from "express";
import * as productController from "../controllers/product.controllers";
import { verificarToken } from "../middlewares/auth.middleware";

const router = Router();

/**
 * @swagger
 * tags:
 *   name: Productos
 *   description: API de gestión de productos (Productor/Empresa)
 */

/**
 * @swagger
 * /api/productos:
 *   get:
 *     summary: Listar productos con filtros
 *     tags: [Productos]
 *     parameters:
 *       - in: query
 *         name: tipo
 *         schema:
 *           type: string
 *         description: Filtrar por tipo de producto
 *       - in: query
 *         name: minPrecio
 *         schema:
 *           type: number
 *         description: Precio mínimo
 *       - in: query
 *         name: maxPrecio
 *         schema:
 *           type: number
 *         description: Precio máximo
 *       - in: query
 *         name: disponible
 *         schema:
 *           type: boolean
 *         description: Filtrar por disponibilidad
 *       - in: query
 *         name: search
 *         schema:
 *           type: string
 *         description: Buscar por nombre o descripción
 *     responses:
 *       200:
 *         description: Lista de productos obtenida exitosamente
 */
router.get("/", productController.getProducts);

/**
 * @swagger
 * /api/productos/{id}:
 *   get:
 *     summary: Ver detalle de un producto
 *     tags: [Productos]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Detalle del producto obtenido
 *       404:
 *         description: Producto no encontrado
 */
router.get("/:id", productController.getProductById);

/**
 * @swagger
 * /api/productos:
 *   post:
 *     summary: Crear un nuevo producto
 *     tags: [Productos]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - nombre
 *               - tipo
 *               - precio
 *             properties:
 *               nombre:
 *                 type: string
 *                 example: Papa Criolla
 *               tipo:
 *                 type: string
 *                 example: Tubérculo
 *               precio:
 *                 type: number
 *                 example: 2500.50
 *               descripcion:
 *                 type: string
 *                 example: Papa fresca recién cosechada
 *               unidad_medida:
 *                 type: string
 *                 example: kg
 *               stock:
 *                 type: number
 *                 example: 100
 *               id_ubicacion:
 *                 type: number
 *                 example: 1
 *     responses:
 *       201:
 *         description: Producto creado exitosamente
 *       401:
 *         description: No autenticado
 */
router.post("/", verificarToken, productController.createProduct);

/**
 * @swagger
 * /api/productos/{id}:
 *   put:
 *     summary: Editar un producto existente
 *     tags: [Productos]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               nombre:
 *                 type: string
 *               tipo:
 *                 type: string
 *               precio:
 *                 type: number
 *               descripcion:
 *                 type: string
 *               stock:
 *                 type: number
 *               disponible:
 *                 type: boolean
 *     responses:
 *       200:
 *         description: Producto actualizado exitosamente
 *       403:
 *         description: No tienes permiso para editar este producto
 *       404:
 *         description: Producto no encontrado
 */
router.put("/:id", verificarToken, productController.updateProduct);

/**
 * @swagger
 * /api/productos/{id}:
 *   delete:
 *     summary: Eliminar un producto
 *     tags: [Productos]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Producto eliminado
 *       403:
 *         description: No tienes permiso para eliminar este producto
 *       404:
 *         description: Producto no encontrado
 */
router.delete("/:id", verificarToken, productController.deleteProduct);

export default router;

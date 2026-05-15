const express = require('express');
const router = express.Router();
const {
  getCategories,
  getPrestataires,
  getPrestataire,
  createService,
  uploadServiceImage,
  getMesServices,
  updateService,
  deleteService
} = require('../controllers/service.controller');
const { authMiddleware } = require('../middleware/auth.middleware');

router.get('/categories', getCategories);
router.get('/prestataires', getPrestataires);
router.get('/prestataires/:id', getPrestataire);
router.get('/mes-services', authMiddleware, getMesServices);
router.post('/', authMiddleware, uploadServiceImage, createService);
router.put('/:id', authMiddleware, uploadServiceImage, updateService);
router.delete('/:id', authMiddleware, deleteService);

module.exports = router;
